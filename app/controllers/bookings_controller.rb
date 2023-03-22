require "google/apis/calendar_v3"
require "google/api_client/client_secrets.rb"
require 'active_support/time'

class BookingsController < ApplicationController
  before_action :authenticate_user!, except: [:choose_reservation, :landing_reservation, :finish_reservation_missing, :finish_reservation_exist, :create]

  CALENDAR_ID = 'primary'


  def landing_reservation
    @user = User.find_by(token: reservation_params[:token])
    @formules = @user.formules
  end

  def choose_reservation
    @user = User.find_by(token: reservation_params[:token])
    @formule = Formule.find(reservation_params[:formule_id])
    if reservation_params[:booking_option] == "yes"
      @existing_user = true
    else
      @existing_user = false
    end
    interval = @formule.duration
    slot_duration = @formule.duration
    start_time = Time.zone.parse('9:00am')
    end_time = Time.zone.parse('21:00pm') - slot_duration
    days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    num_weeks = 4
    excluded_fixed_weekly_slots = [
      ['Monday', '1pm', '2pm'],
      ['Tuesday', '1pm', '2pm'],
      ['Wednesday', '1pm', '2pm'],
      ['Thursday', '1pm', '2pm'],
      ['Friday', '1pm', '2pm']
    ]
    @user_bookings = @user.bookings.upcoming_all
    # Generate the available datetimes using the generate_datetimes function
    full_datetimes = generate_datetimes(start_time, end_time, days_of_week, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots)
    @full_datetimes = full_datetimes
  end

  def finish_reservation_exist
    @existing_user = reservation_params[:existing_user]
    @user = User.find_by(token: reservation_params[:token])
    @formule = Formule.find_by(id: reservation_params[:formule].to_i)
    @datetime = reservation_params[:datetime]
    @booking = Booking.new
  end

  def finish_reservation_missing
    @existing_user = reservation_params[:existing_user]
    @user = User.find_by(token: reservation_params[:token])
    @formule = Formule.find_by(id: reservation_params[:formule].to_i)
    @datetime = reservation_params[:datetime]
    @booking = Booking.new
    @client = Client.new
  end

  def new
    @booking = Booking.new
  end

  def show
    @booking = Booking.find(params[:id])
    @client_data_hash = get_client_data(@booking.client.id)
    @marker = {
      lat: @booking.formule.latitude,
      lng: @booking.formule.longitude,
      info_window_html: render_to_string(partial: "info_window", locals: { booking: @booking })
    }
    @previous_page = params[:format]
    @calendar_bookings = current_user.bookings.where("start_time BETWEEN ? AND ? AND status = 'Accepted'", 2.months.ago, 2.months.from_now)
  end

  def index
    user_bookings = current_user.bookings
    @today_bookings = user_bookings.today
    @tomorrow_bookings = user_bookings.tomorrow
    @this_week_bookings = user_bookings.this_week
    @next_week_bookings = user_bookings.next_week
    @next_bookings = user_bookings.next_bookings
    @next_month_bookings = user_bookings.next_month
    @after_bookings = user_bookings.after
    @passed_bookings = user_bookings.passed_confirmed

    @today_pending_bookings = user_bookings.today_pending
    @tomorrow_pending_bookings = user_bookings.tomorrow_pending
    @this_week_pending_bookings = user_bookings.this_week_pending
    @next_week_pending_bookings = user_bookings.next_week_pending
    @next_month_pending_bookings = user_bookings.next_month_pending
    @after_pending_bookings = user_bookings.after_pending
  end

  def confirm
    @booking = Booking.find(params[:id])
    @booking.update(status: "Accepted")
    flash[:notice] = "Demande de réservation acceptée !"
    redirect_to bookings_path
  end

  def refuse
    @booking = Booking.find(params[:id])
    @booking.update(status: "Refused")
    flash[:notice] = "Demande de réservation refusée !"
    redirect_to bookings_path
  end

  def create
    if params[:booking][:client].present? && !params[:booking][:client].key?(:first_name)
      client_email = booking_params[:client][:email]
      client = Client.find_by(email: client_email)
      @user = User.find(booking_params[:user_id])
      if client
        @booking = Booking.new(booking_params.except(:client, :back))
        @booking.client_id = client.id
        @booking.user_id = @user.id
        if @booking.save
          # Handle successful booking creation
          flash[:notice] = "Demande de réservation envoyée !"
          redirect_to landing_reservation_path(@user.token)
        else
          # Handle errors if the booking can't be saved
          flash[:alert] = "Erreur de création réservation"
          redirect_to finish_reservation_exist_path(token: @user.token, datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule], existing_user: params[:booking][:back][:existing_user])
        end
      else
        flash[:alert] = "Adresse email non répertoriée, veuillez effectuer l'inscription"
        @existing_user = false
        redirect_to finish_reservation_missing_path(token: @user.token, datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule], existing_user: params[:booking][:back][:existing_user])
      end
    elsif params[:booking][:client].present? && params[:booking][:client].key?(:first_name)
      @user = User.find(booking_params[:user_id])
      @booking = Booking.new(booking_params.except(:client, :back))
      @client = Client.new(booking_params[:client])
      @client.user_id = @user.id
      if params[:booking][:client][:photo].present?
        @client.photo.attach(params[:booking][:client][:photo])
      end
      if @client.save
        @booking.client_id = @client.id
        @booking.user_id = @user.id
        if @booking.save!
          # Handle successful booking creation
          flash[:notice] = "Demande de réservation envoyée !"
          redirect_to landing_reservation_path(@user.token)
        else
          # Handle errors if the booking can't be saved
          flash[:alert] = "Erreur de création réservation"
          redirect_to finish_reservation_missing_path(token: @user.token, datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule], existing_user: params[:booking][:back][:existing_user])
        end
      else
        flash[:alert] = "Erreur de création contact client"
        redirect_to finish_reservation_missing_path(token: @user.token, datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule], existing_user: params[:booking][:back][:existing_user])
      end
    else
      client = get_google_calendar_client current_user
      booking = params[:booking]
      event = get_event booking
      client.insert_event('primary', event)
      flash[:notice] = 'booking was successfully added.'
      redirect_to bookings_path
    end
  end

  def get_google_calendar_client current_user
    client = Google::Apis::CalendarV3::CalendarService.new
    return unless (current_user.present? && current_user.access_token.present? && current_user.refresh_token.present?)
    secrets = Google::APIClient::ClientSecrets.new({
      "web" => {
        "access_token" => current_user.access_token,
        "refresh_token" => current_user.refresh_token,
        "client_id" => ENV["GOOGLE_API_KEY"],
        "client_secret" => ENV["GOOGLE_API_SECRET"]
      }
    })
    begin
      client.authorization = secrets.to_authorization
      client.authorization.grant_type = "refresh_token"

      if !current_user.present?
        client.authorization.refresh!
        current_user.update_attributes(
          access_token: client.authorization.access_token,
          refresh_token: client.authorization.refresh_token,
          expires_at: client.authorization.expires_at.to_i
        )
      end
    rescue => e
      flash[:error] = 'Your token has been expired. Please login again with google.'
      redirect_to :back
    end
    client
  end

  def disponibilites
    interval = current_user.formules.minimum(:duration)
    slot_duration = current_user.formules.minimum(:duration)
    start_time = Time.zone.parse('9:00am')
    end_time = Time.zone.parse('7:00pm') - slot_duration
    days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    num_weeks = 4
    excluded_fixed_weekly_slots = [
      ['Monday', '1pm', '2pm'],
      ['Tuesday', '1pm', '2pm'],
      ['Wednesday', '1pm', '2pm'],
      ['Thursday', '1pm', '2pm'],
      ['Friday', '1pm', '2pm']
    ]

    # Update available datetimes with newly cancelled or added slots
    if params[:cancelled_slot]
      @cancelled_slot = Time.zone.parse(params[:cancelled_slot])
      @weekly_index = params[:weekly_index].to_i
      @daily_index = params[:daily_index].to_i
      cancelled_booking = Booking.new(start_time: @cancelled_slot, end_time: @cancelled_slot + slot_duration.minutes, status:"Accepted", cancel_type: "Cancelled")
      cancelled_booking.user_id = current_user.id
      cancelled_booking.save
    elsif params[:added_slot]
      @weekly_index = params[:added_slot][:weekly_index].to_i
      @daily_index = params[:added_slot][:daily_index].to_i
      date = Time.zone.parse(params[:added_slot][:day])
      time = Time.zone.parse(params[:added_slot][:added_slot])
      datetime = Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
      added_slot = Available.new(start_time: datetime, end_time: datetime + slot_duration.minutes)
      added_slot.user_id = current_user.id
      added_slot.save
    end

    @user_bookings = current_user.bookings.upcoming_all
    # Generate the available datetimes using the generate_datetimes function
    available_datetimes = generate_datetimes(start_time, end_time, days_of_week, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots)

    @full_datetimes = available_datetimes



    if params[:cancelled_slot] || params[:added_slot]
      render turbo_stream:
        turbo_stream.replace("daily-card-#{@weekly_index}-#{@daily_index}",
        partial: "bookings/daily_card",
        locals: { daily_datetimes: @full_datetimes[@weekly_index][@daily_index], daily_index: @daily_index, weekly_index: @weekly_index })
    end

  end


  private

  def reservation_params
    params.permit(:formule_id, :formule, :booking_option, :token, :existing_user, :datetime)
  end

  def booking_params
    params.require(:booking).permit(:start_time, :end_time, :payment_status, :price, :user_id, :booking_type, :message, :formule_id, client: [:email, :first_name, :last_name, :phone_number, :photo], back: [:datetime, :formule, :existing_user])
  end

  def get_event booking
    # attendees = booking[:members].split(',').map{ |t| {email: t.strip} }
    event = Google::Apis::CalendarV3::Event.new({
      summary: booking[:title],
      location: '800 Howard St., San Francisco, CA 94103',
      description: booking[:description],
      start: {
        date_time: Time.new(booking['start_date(1i)'],booking['start_date(2i)'],booking['start_date(3i)'],booking['start_date(4i)'],booking['start_date(5i)']).to_datetime.rfc3339,
        time_zone: "Asia/Kolkata"
        # date_time: '2019-09-07T09:00:00-07:00',
        # time_zone: 'Asia/Kolkata',
      },
    end: {
      date_time: Time.new(booking['end_date(1i)'],booking['end_date(2i)'],booking['end_date(3i)'],booking['end_date(4i)'],booking['end_date(5i)']).to_datetime.rfc3339,
      time_zone: "Asia/Kolkata"
    },
    # attendees: attendees,
    reminders: {
      use_default: false,
      overrides: [
        Google::Apis::CalendarV3::EventReminder.new(reminder_method:"popup", minutes: 10),
        Google::Apis::CalendarV3::EventReminder.new(reminder_method:"email", minutes: 20)
      ]
    },
    notification_settings: {
      notifications: [
        {type: 'event_creation', method: 'email'},
        {type: 'event_change', method: 'email'},
        {type: 'event_cancellation', method: 'email'},
        {type: 'event_response', method: 'email'}
      ]
      }, 'primary': true
      })
    end



  def generate_datetimes(start_time, end_time, given_days_of_week, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots)
    Time.zone = 'Europe/Paris'
    full_datetimes = []
    weekly_datetimes = []
    daily_datetimes = []
    current_time = Time.zone.now

    converted_available_slots = convert_available_slots(current_user.availables)

    (0..num_weeks - 1).each do |week_num|
      given_days_of_week.each do |day|
        target_day = Date.parse(day)
        target_day += (7 * week_num)
        slot = Time.zone.local(target_day.year, target_day.month, target_day.day, start_time.hour, start_time.min, start_time.sec)
        while slot <= Time.zone.local(target_day.year, target_day.month, target_day.day, end_time.hour, end_time.min, end_time.sec)
          excluded = false
          excluded_fixed_weekly_slots.each do |fw_slot|
            fw_day_of_week = fw_slot[0]
            fw_start_time = Time.zone.parse(fw_slot[1])
            fw_end_time = Time.zone.parse(fw_slot[2])
            if slot.strftime("%A") == fw_day_of_week && slot >= Time.zone.local(slot.year, slot.month, slot.day, fw_start_time.hour, fw_start_time.min, 0) && slot + slot_duration.minutes <= Time.zone.local(slot.year, slot.month, slot.day, fw_end_time.hour, fw_end_time.min, 0)
              excluded = true
              break
            end
          end
          daily_datetimes << slot unless excluded || slot < current_time
          slot += interval.minutes
        end

        # Add converted_available_slots to the daily_datetimes array before calling sort_bookings
        converted_available_slots.each do |available_slot|
          target_day = Date.parse(day) + (7 * week_num)
          if available_slot.to_date == target_day && !daily_datetimes.include?(available_slot)
            daily_datetimes << available_slot
          end
        end
        daily_datetimes.sort!

        # Call sort_bookings after adding converted_available_slots
        sort_bookings(daily_datetimes, slot_duration)

        weekly_datetimes << daily_datetimes unless daily_datetimes.empty?
        daily_datetimes = []
      end
      full_datetimes << weekly_datetimes
      weekly_datetimes = []
    end

    full_datetimes
  end

  def convert_available_slots(available_slots)
    converted_slots = []
    available_slots.each do |slot|
      slot_start = slot.start_time
      converted_slots << slot_start
    end
    converted_slots
  end


  def sort_bookings(daily_datetimes, slot_duration)
    overlapping_slots = []
    daily_datetimes.each do |slot|
      slot_end = slot + slot_duration.minutes
      @user_bookings.each do |booking|
        if (slot >= booking.start_time && slot < booking.end_time) ||
           (slot_end > booking.start_time && slot_end <= booking.end_time)
          overlapping_slots << slot
          break # Exit the inner loop early
        end
      end
    end
    daily_datetimes.reject! { |slot| overlapping_slots.include?(slot) }
  end


  def get_client_data(client_id)
    client = Client.find(client_id)
    if client.user == current_user
      current_user_bookings = Booking.passed_confirmed.where(client_id: client_id)
      revenues = 0
      bookings_count = current_user_bookings.count
      current_user_bookings.each do |booking|
        revenues += booking.price
      end
      return { client: client, revenues: revenues, bookings_count: bookings_count }
    else
      return nil # return nil if the client does not belong to the current user
    end
  end

end
