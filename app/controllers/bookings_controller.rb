require "google/apis/calendar_v3"
require "google/api_client/client_secrets.rb"
require 'active_support/time'
require 'json'

class BookingsController < ApplicationController
  before_action :authenticate_user!, except: [:choose_reservation, :landing_reservation, :finish_reservation, :create, :confirm_cancel, :cancel, :confirm_suggestion, :confirm_suggestion_update]

  before_action :check_onboarding_status, except: [:choose_reservation, :landing_reservation, :finish_reservation, :create, :confirm_cancel, :cancel, :confirm_suggestion, :confirm_suggestion_update]

  def check_onboarding_status
    if current_user && !current_user.step_1
      redirect_to onboarding_path(step: 'step1')
    elsif current_user && !current_user.step_2
      redirect_to onboarding_path(step: 'step2')
    elsif current_user && !current_user.step_3
      redirect_to onboarding_path(step: 'step3')
    elsif current_user && !current_user.step_4
      redirect_to onboarding_path(step: 'step4')
    end
  end

  CALENDAR_ID = 'primary'


  def landing_reservation
    @user = User.find_by(token: reservation_params[:token])
    @formules = @user.formules.active
    @tags = @user.tags
    ahoy.track "Viewed coach", {coach_id: @user.id} unless current_user == @user
  end

  def choose_reservation
    @user = User.find_by(token: reservation_params[:token])
    @formule = Formule.find(reservation_params[:formule_id])
    interval = @user.formules.minimum(:duration)
    slot_duration = @formule.duration
    start_time = Time.zone.parse(@user.daily_start_time)
    end_time = Time.zone.parse(@user.daily_end_time)
    days_of_week = @user.days_of_week
    num_weeks = 4
    if @user.excluded_fixed_weekly_slots.is_a?(String)
      excluded_fixed_weekly_slots = JSON.parse(@user.excluded_fixed_weekly_slots)
    else
      excluded_fixed_weekly_slots = @user.excluded_fixed_weekly_slots
    end
    puts "HERE IN CHOOSE THE EXCLUDED IS THE FOLLOWING"
    puts "================="
    p excluded_fixed_weekly_slots
    @user_bookings = @user.bookings.upcoming_all
    # Generate the available datetimes using the generate_datetimes function
    full_datetimes = generate_datetimes(start_time, end_time, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots, @user)
    @full_datetimes = full_datetimes
  end

  def finish_reservation
    @user = User.find_by(token: reservation_params[:token])
    @formule = Formule.find_by(id: reservation_params[:formule].to_i)
    @datetime = reservation_params[:datetime]
    @booking = Booking.new
    @client = Client.new
  end

  def new
    @user = current_user
    @formules = @user.formules.active
  end

  def new_choose_reservation
    @user = current_user
    @formule = Formule.find(reservation_params[:formule_id])
    interval = @user.formules.minimum(:duration)
    slot_duration = @formule.duration
    start_time = Time.zone.parse(@user.daily_start_time)
    end_time = Time.zone.parse(@user.daily_end_time)
    days_of_week = @user.days_of_week
    num_weeks = 4
    if current_user.excluded_fixed_weekly_slots.is_a?(String)
      excluded_fixed_weekly_slots = JSON.parse(current_user.excluded_fixed_weekly_slots)
    else
      excluded_fixed_weekly_slots = current_user.excluded_fixed_weekly_slots
    end
    @user_bookings = @user.bookings.upcoming_all
    # Generate the available datetimes using the generate_datetimes function
    full_datetimes = generate_datetimes(start_time, end_time, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots, @user)
    @full_datetimes = full_datetimes
  end

  def new_finish_reservation
    @user = current_user
    @formule = Formule.find_by(id: reservation_params[:formule].to_i)
    @datetime = reservation_params[:datetime]
    @booking = Booking.new
    @client = Client.new
    @clients = @user.clients
  end

  def date_new_reservation
    @user = current_user
    @formules = @user.formules.active
    @datetime = params[:datetime]
    @jour = params[:jour]
    if @jour
      interval = @user.formules.minimum(:duration)
      slot_duration = @user.formules.minimum(:duration)
      start_time = Time.zone.parse(@user.daily_start_time)
      end_time = Time.zone.parse(@user.daily_end_time)
      days_of_week = @user.days_of_week
      num_weeks = 4
      if current_user.excluded_fixed_weekly_slots.is_a?(String)
        excluded_fixed_weekly_slots = JSON.parse(current_user.excluded_fixed_weekly_slots)
      else
        excluded_fixed_weekly_slots = current_user.excluded_fixed_weekly_slots
      end
      @datetimes = generate_day_datetimes(start_time, end_time, interval, slot_duration, excluded_fixed_weekly_slots, @user, @jour)
    end
  end

  def date_new_finish_reservation
    @user = current_user
    @formule = Formule.find(params[:formule_id])
    if params[:jour]
      @datetime = Time.zone.parse("#{params[:jour]} #{params[:time]}").to_s
    else
      @datetime = params[:datetime]
    end
    @booking = Booking.new
    @client = Client.new
    @clients = @user.clients
  end

  def client_new_reservation
    @user = current_user
    @formules = @user.formules.active
    @client = Client.find(params[:client_id])
  end

  def client_new_finish_reservation
    @user = current_user
    @formule = Formule.find(params[:formule_id])
    @client = Client.find(params[:client_id])
    interval = @user.formules.minimum(:duration)
    slot_duration = @formule.duration
    start_time = Time.zone.parse(@user.daily_start_time)
    end_time = Time.zone.parse(@user.daily_end_time)
    days_of_week = @user.days_of_week
    num_weeks = 5
    if @user.excluded_fixed_weekly_slots.is_a?(String)
      excluded_fixed_weekly_slots = JSON.parse(@user.excluded_fixed_weekly_slots)
    else
      excluded_fixed_weekly_slots = @user.excluded_fixed_weekly_slots
    end
    @user_bookings = @user.bookings.upcoming_all
    # Generate the available datetimes using the generate_datetimes function
    full_datetimes = generate_datetimes(start_time, end_time, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots, @user)
    @full_datetimes = full_datetimes
  end

  def client_confirm_reservation
    @user = current_user
    @formule = Formule.find(params[:formule].to_i)
    @client = Client.find(params[:client_id].to_i)
    @datetime = params[:datetime]
    @booking = Booking.new
  end

  def show
    @user = current_user
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
    @after_pending_bookings = user_bookings.after_pending
  end

  def confirm
    @booking = Booking.find(params[:id])
    @user = @booking.user
    @client = @booking.client
    @booking.update(status: "Accepted")
    flash[:notice] = "Demande de réservation acceptée !"
    redirect_to bookings_path
    BookingMailer.user_booking_email(@user, @booking).deliver_later if Rails.env.production?
    BookingMailer.client_booking_email(@client, @booking).deliver_later if Rails.env.production?
  end

  def refuse
    @booking = Booking.find(params[:id])
    @user = @booking.user
    @client = @booking.client
    refusal_message = params[:booking][:refusal_message].blank? ? "Réservation annulée" : params[:booking][:refusal_message]
    @booking.update(status: "Refused", refusal_message: refusal_message)
    flash[:notice] = "Demande de réservation refusée !"
    redirect_to bookings_path
    BookingMailer.user_booking_email_refuse(@user, @booking).deliver_later if Rails.env.production?
    BookingMailer.client_booking_email_refuse(@client, @booking).deliver_later if Rails.env.production?
  end

  def confirm_cancel
    @booking = Booking.find_by(cancellation_token: params[:cancellation_token])
    @user = @booking.user
    @formule = @booking.formule
    unless @booking
      flash[:alert] = 'Mauvais identifiant veuillez réessayer ultérieurement'
      redirect_to root_path
    end
  end

  def cancel
    @booking = Booking.find_by!(cancellation_token: params[:cancellation_token])
    @user = @booking.user
    @client = @booking.client
    @booking.update(status: 'Refused')
    push_message = "#{@client.full_name} - #{l(@booking.start_time, format: '%e %B')} #{l(@booking.start_time, format: '%H')}h#{l(@booking.start_time, format: '%M')} à #{l(@booking.end_time, format: '%H')}h#{l(@booking.end_time, format: '%M')}"
    push_url = "/"
    title = "Réservation annulée par ton client"
    PushNotificationService.send(@user, title, push_message, push_url)
    BookingMailer.user_booking_email_refuse_client(@user, @booking).deliver_later if Rails.env.production?
    BookingMailer.client_booking_email_refuse_client(@client, @booking).deliver_later if Rails.env.production?
  end

  def confirm_suggestion
    @booking = Booking.find_by(cancellation_token: params[:cancellation_token])
    @user = @booking.user
    @formule = @booking.formule
    unless @booking
      flash[:alert] = 'Mauvais identifiant veuillez réessayer ultérieurement'
      redirect_to root_path
    end
  end

  def confirm_suggestion_update
    @booking = Booking.find_by!(cancellation_token: params[:cancellation_token])
    @user = @booking.user
    @client = @booking.client
    @booking.update(status: 'Accepted')
    push_message = "#{@client.full_name} - #{l(@booking.start_time, format: '%e %B')} #{l(@booking.start_time, format: '%H')}h#{l(@booking.start_time, format: '%M')} à #{l(@booking.end_time, format: '%H')}h#{l(@booking.end_time, format: '%M')}"
    push_url = "/bookings/#{@booking.id}.bookings_path"
    title = "Réservation confirmée par ton client"
    PushNotificationService.send(@user, title, push_message, push_url)
    BookingMailer.user_booking_email(@user, @booking).deliver_later if Rails.env.production?
    BookingMailer.client_booking_email(@client, @booking).deliver_later if Rails.env.production?
  end

  def edit_schedule
    @user = current_user
    @booking = Booking.find(params[:id])
    @formule = @booking.formule
    interval = @user.formules.minimum(:duration)
    slot_duration = @formule.duration
    start_time = Time.zone.parse(@user.daily_start_time)
    end_time = Time.zone.parse(@user.daily_end_time)
    days_of_week = @user.days_of_week
    num_weeks = 4
    if @user.excluded_fixed_weekly_slots.is_a?(String)
      excluded_fixed_weekly_slots = JSON.parse(@user.excluded_fixed_weekly_slots)
    else
      excluded_fixed_weekly_slots = @user.excluded_fixed_weekly_slots
    end
    # Generate the available datetimes using the generate_datetimes function
    full_datetimes = generate_datetimes(start_time, end_time, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots, @user)
    @full_datetimes = full_datetimes
  end

  def update_schedule
    @booking = Booking.find(params[:id])
    @user = @booking.user
    @client = @booking.client
    if @booking.update(booking_time_params)
      redirect_to booking_path(@booking), notice: 'Réservation modifée avec succès, ton client est informé par e-mail'
      BookingMailer.user_booking_email_modif_time(@user, @booking).deliver_later if Rails.env.production? && !@user.admin?
      BookingMailer.client_booking_email_modif_time(@client, @booking).deliver_later if Rails.env.production? && !@user.admin?
    else
      render :edit
    end
  end

  def suggest_schedule
    @user = current_user
    @booking = Booking.find(params[:id])
    @formule = @booking.formule
    interval = @user.formules.minimum(:duration)
    slot_duration = @formule.duration
    start_time = Time.zone.parse(@user.daily_start_time)
    end_time = Time.zone.parse(@user.daily_end_time)
    days_of_week = @user.days_of_week
    num_weeks = 4
    if @user.excluded_fixed_weekly_slots.is_a?(String)
      excluded_fixed_weekly_slots = JSON.parse(@user.excluded_fixed_weekly_slots)
    else
      excluded_fixed_weekly_slots = @user.excluded_fixed_weekly_slots
    end
    # Generate the available datetimes using the generate_datetimes function
    full_datetimes = generate_datetimes(start_time, end_time, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots, @user)
    @full_datetimes = full_datetimes
  end

  def update_suggest
    @booking = Booking.find(params[:id])
    @user = @booking.user
    @client = @booking.client
    if @booking.update(booking_time_params)
      @booking.update_column(:pending_slot_suggestion, true)
      redirect_to booking_path(@booking), notice: 'La proposition de créneau a été envoyée à ton client par e-mail'
      BookingMailer.user_booking_email_modif_time_confirm(@user, @booking).deliver_later if Rails.env.production? && !@user.admin?
      BookingMailer.client_booking_email_modif_time_confirm(@client, @booking).deliver_later if Rails.env.production? && !@user.admin?
    else
      render :edit
    end
  end


  def create
    if params[:booking][:status] == "Accepted"

      if params[:booking][:origin] == "client_new_finish"
        client_id = params[:booking][:client_id].to_i
        @client = Client.find(client_id)
        @user = current_user
        @booking = Booking.new(client_booking_params)
        @booking.client_id = @client.id
        @booking.user_id = @user.id

        if @booking.save
          flash[:notice] = "Réservation ajoutée !"
          redirect_to root_path

          BookingMailer.user_booking_email(@user, @booking).deliver_now if Rails.env.production? && !@user.admin?
          BookingMailer.client_booking_email(@client, @booking).deliver_now if Rails.env.production? && !@user.admin?
        else
          flash[:alert] = "Erreur de création réservation"
          redirect_to client_confirm_reservation_path(client_id: params[:client_id], datetime: params[:start_time], formule: params[:formule_id])
        end

      elsif params[:booking][:client].present? && !params[:booking][:client].key?(:first_name)
        client_id = booking_params[:client][:id]
        @client = Client.find(client_id)
        @user = current_user
        @booking = Booking.new(booking_params.except(:client, :back))
        @booking.client_id = @client.id
        @booking.user_id = @user.id

        if @booking.save
          flash[:notice] = "Réservation ajoutée !"
          redirect_to root_path

          BookingMailer.user_booking_email(@user, @booking).deliver_now if Rails.env.production? && !@user.admin?
          BookingMailer.client_booking_email(@client, @booking).deliver_now if Rails.env.production? && !@user.admin?
        else
          if params[:booking][:origin] == "date_new_finish"
            flash[:alert] = "Erreur de création réservation"
            redirect_to date_new_finish_reservation_path(datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule])
          else
            flash[:alert] = "Erreur de création réservation"
            redirect_to new_finish_reservation_path(datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule])
          end
        end

      elsif params[:booking][:client].present? && params[:booking][:client].key?(:first_name)
        @user = current_user
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
            flash[:notice] = "Réservation ajoutée !"
            redirect_to root_path
            BookingMailer.user_booking_email(@user, @booking).deliver_later if Rails.env.production? && !@user.admin?
            BookingMailer.client_booking_email(@client, @booking).deliver_later if Rails.env.production? && !@user.admin?
          else
            if params[:booking][:origin] == "date_new_finish"
              flash[:alert] = "Erreur de création réservation"
              redirect_to date_new_finish_reservation_path(datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule])
            else
              flash[:alert] = "Erreur de création réservation"
              redirect_to new_finish_reservation_path(datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule])
            end
          end
        else
          if params[:booking][:origin] == "date_new_finish"
            flash[:alert] = "Erreur de création contact client, renseigner tous les champs"
            redirect_to date_new_finish_reservation_path(datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule])
          else
            flash[:alert] = "Erreur de création contact client, renseigner tous les champs"
            redirect_to new_finish_reservation_path(datetime: params[:booking][:back][:datetime], formule: params[:booking][:back][:formule])
          end
        end
      end

    else

      if params[:booking][:client].present? && !params[:booking][:client].key?(:first_name)
        client_email = booking_params[:client][:email]
        @client = Client.find_by(email: client_email)
        @user = User.find(booking_params[:user_id])
        if @client
          @booking = Booking.new(booking_params.except(:client, :back))
          @booking.client_id = @client.id
          @booking.user_id = @user.id

          if @booking.save
            flash[:notice] = "Demande de réservation envoyée !"
            redirect_to landing_reservation_path(@user.token)

            push_message = "#{@client.full_name} - #{l(@booking.start_time, format: '%e %B')} #{l(@booking.start_time, format: '%H')}h#{l(@booking.start_time, format: '%M')} à #{l(@booking.end_time, format: '%H')}h#{l(@booking.end_time, format: '%M')}"
            push_url = "/bookings/#{@booking.id}"
            title = "Nouvelle demande de réservation Chuck"
            PushNotificationService.send(@user, title, push_message, push_url)

            BookingMailer.user_booking_email_pending(@user, @booking).deliver_later if Rails.env.production? && !@user.admin?
            BookingMailer.client_booking_email_pending(@client, @booking).deliver_later if Rails.env.production? && !@user.admin?
          else
            flash[:alert] = "Erreur de demande réservation"
            redirect_to new_landing_reservation_path(token: @user.token)
          end
        else
          flash[:alert] = "Erreur de demande réservation - Client introuvable"
          redirect_to new_landing_reservation_path(token: @user.token)
        end

      elsif params[:booking][:client].present? && params[:booking][:client].key?(:first_name)
        @user = User.find(booking_params[:user_id])
        @client = Client.new(booking_params[:client])
        @client.user_id = @user.id

        if @client.save
          @booking = Booking.new(booking_params.except(:client, :back))
          @booking.client_id = @client.id
          @booking.user_id = @user.id

          if @booking.save
            flash[:notice] = "Demande de réservation envoyée !"
            redirect_to landing_reservation_path(@user.token)

            push_message = "#{@client.full_name} - #{l(@booking.start_time, format: '%e %B')} #{l(@booking.start_time, format: '%H')}h#{l(@booking.start_time, format: '%M')} à #{l(@booking.end_time, format: '%H')}h#{l(@booking.end_time, format: '%M')}"
            push_url = "/bookings/#{@booking.id}"
            title = "Nouvelle demande de réservation Chuck"
            PushNotificationService.send(@user, title, push_message, push_url)

            BookingMailer.user_booking_email_pending(@user, @booking).deliver_later if Rails.env.production? && !@user.admin?
            BookingMailer.client_booking_email_pending(@client, @booking).deliver_later if Rails.env.production? && !@user.admin?
          else
            flash[:alert] = "Erreur de demande réservation"
            redirect_to new_landing_reservation_path(token: @user.token)
          end
        else
          flash[:alert] = "Erreur de création contact client, renseigner tous les champs"
          redirect_to new_landing_reservation_path(token: @user.token)
        end
      end
    end
  end



  def disponibilites

    # // FOR WEEKLY
    start_date = Date.today.beginning_of_week
    end_date = 6.months.from_now.end_of_week
    @weeks = (start_date..end_date).step(7).to_a
    # // FOR DAILY
    interval = current_user.formules.minimum(:duration)
    @slot_duration = current_user.formules.minimum(:duration)
    start_time = Time.zone.parse(current_user.daily_start_time)
    end_time = Time.zone.parse(current_user.daily_end_time)
    @days_of_week = current_user.days_of_week
    num_weeks = 4
    if current_user.excluded_fixed_weekly_slots.is_a?(String)
      excluded_fixed_weekly_slots = JSON.parse(current_user.excluded_fixed_weekly_slots)
    else
      excluded_fixed_weekly_slots = current_user.excluded_fixed_weekly_slots
    end
    # Update available datetimes with newly cancelled or added slots
    if params[:cancelled_slot]
      @cancelled_slot = Time.zone.parse(params[:cancelled_slot])
      @weekly_index = params[:weekly_index].to_i
      @daily_index = params[:daily_index].to_i
      available_booking = Available.find_by(start_time: @cancelled_slot, end_time: @cancelled_slot + @slot_duration.minutes)
      if available_booking
        available_booking.destroy
      else
        cancelled_booking = Booking.new(start_time: @cancelled_slot, end_time: @cancelled_slot + @slot_duration.minutes, status:"Accepted", cancel_type: "Cancelled")
        cancelled_booking.user_id = current_user.id
        cancelled_booking.save
      end
    elsif params[:added_slot]
      @weekly_index = params[:added_slot][:weekly_index].to_i
      @daily_index = params[:added_slot][:daily_index].to_i
      date = Time.zone.parse(params[:added_slot][:day])
      time = Time.zone.parse(params[:added_slot][:added_slot])
      datetime = Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)

      # Check if there's a booking with the same start_time and cancel_type: "Cancelled"
      cancelled_booking = Booking.find_by(start_time: datetime, cancel_type: "Cancelled", user_id: current_user.id)

      if cancelled_booking
        # Destroy the cancelled booking
        cancelled_booking.destroy
      else
        # Create a new availability
        added_slot = Available.new(start_time: datetime, end_time: datetime + @slot_duration.minutes)
        added_slot.user_id = current_user.id
        added_slot.save
      end
    end


    @user_bookings = current_user.bookings.upcoming_all
    # Generate the available datetimes using the generate_datetimes function
    available_datetimes = generate_datetimes(start_time, end_time, interval, num_weeks, @slot_duration, excluded_fixed_weekly_slots)

    @full_datetimes = available_datetimes



    if params[:cancelled_slot]
      puts "Sending Turbo Stream to update daily card..."
      render turbo_stream:
        turbo_stream.replace("daily-card-#{@weekly_index}-#{@daily_index}",
        partial: "bookings/daily_card",
        locals: { daily_datetimes: @full_datetimes[@weekly_index][@daily_index], daily_index: @daily_index, weekly_index: @weekly_index })
    end

  end

  def update_availability
    availability = AvailabilityWeek.find(params[:id])
    puts availability
    puts availability_week_params
    availability.update(availability_week_params)
  end

  private

  def reservation_params
    params.permit(:formule_id, :formule, :booking_option, :token, :datetime)
  end

  def booking_params
    params.require(:booking).permit(:start_time, :end_time, :payment_status, :price, :user_id, :booking_type, :message, :formule_id, :status, :cancellation_token, client: [:email, :first_name, :last_name, :phone_number, :photo, :id], back: [:datetime, :formule])
  end

  def client_booking_params
    params.require(:booking).permit(:start_time, :end_time, :payment_status, :price, :user_id, :booking_type, :message, :formule_id, :status)
  end

  def availability_week_params
    params.require(:availability_week).permit(:week_enabled, :available_monday, :available_tuesday, :available_wednesday, :available_thursday, :available_friday, :available_saturday, :available_sunday)
  end

  def booking_time_params
    params.require(:booking).permit(:start_time, :end_time)
  end



  # def generate_datetimes(start_time, end_time, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots, user = nil, booking_start_time = nil)
  #   Time.zone = 'Europe/Paris'
  #   full_datetimes = []
  #   weekly_datetimes = []
  #   daily_datetimes = []
  #   current_time = booking_start_time || Time.zone.now
  #   user ||= current_user
  #   given_days_of_week = user.days_of_week
  #   converted_available_slots = convert_available_slots(user.availables)
  #   availability_weeks = user.availability_weeks

  #   week_num = 0
  #   while week_num < num_weeks
  #     formatted_current_week_start = (current_time.beginning_of_week + week_num.weeks).strftime("%a, %d %b %Y")
  #     availability_week = availability_weeks.find { |aw| aw.week_start.strftime("%a, %d %b %Y") == formatted_current_week_start }

  #     if availability_week && !availability_week.week_enabled
  #       full_datetimes << []
  #     else
  #       given_days_of_week.each do |day|
  #         next if availability_week && !availability_week["available_#{day.downcase}"]

  #         first_day_of_week = current_time.beginning_of_week + week_num.weeks
  #         day_offset = (Date.parse(day).wday - first_day_of_week.wday) % 7
  #         target_day = first_day_of_week + day_offset.days

  #         slot = Time.zone.local(target_day.year, target_day.month, target_day.day, start_time.hour, start_time.min, start_time.sec)
  #         while slot <= Time.zone.local(target_day.year, target_day.month, target_day.day, end_time.hour, end_time.min, end_time.sec)
  #           excluded = false
  #           client_booking = user.bookings.upcoming_all.find { |b| b.start_time == slot && b.cancel_type == "Client" }

  #           if client_booking
  #             previous_end_time = client_booking.end_time
  #           end

  #           if previous_end_time && (slot < previous_end_time + user.break_time.minutes)
  #             slot = previous_end_time + user.break_time.minutes
  #           end

  #           if slot + slot_duration.minutes > Time.zone.local(target_day.year, target_day.month, target_day.day, end_time.hour, end_time.min, end_time.sec)
  #             break
  #           end


  #           excluded_fixed_weekly_slots.each do |fw_slot|
  #             fw_day_of_week = fw_slot[0]
  #             fw_start_time = Time.zone.parse(fw_slot[1])
  #             fw_end_time = Time.zone.parse(fw_slot[2])
  #             fw_start_time_on_slot_day = Time.zone.local(slot.year, slot.month, slot.day, fw_start_time.hour, fw_start_time.min, 0)
  #             fw_end_time_on_slot_day = Time.zone.local(slot.year, slot.month, slot.day, fw_end_time.hour, fw_end_time.min, 0)
  #             if slot.strftime("%A") == fw_day_of_week && (slot...slot + slot_duration.minutes).overlaps?(fw_start_time_on_slot_day...fw_end_time_on_slot_day)
  #               excluded = true
  #               break
  #             end
  #           end

  #           daily_datetimes << slot unless excluded || slot.to_date < current_time.to_date

  #           slot += interval.minutes
  #         end

  #         converted_available_slots.each do |available_slot|
  #           if available_slot.to_date == target_day.to_date && available_slot.to_date >= current_time.to_date && !daily_datetimes.include?(available_slot)
  #             daily_datetimes << available_slot
  #           end
  #         end

  #         daily_datetimes.sort!
  #         sort_bookings(daily_datetimes, slot_duration, user)

  #         weekly_datetimes << daily_datetimes unless daily_datetimes.empty?
  #         daily_datetimes = []
  #       end
  #     end

  #     # Only increment week_num if there are available slots
  #     if weekly_datetimes.any?
  #       full_datetimes << weekly_datetimes
  #       week_num += 1
  #     end
  #     weekly_datetimes = []

  #     # Always move to the next week to check availability
  #     current_time = current_time + 1.week
  #   end

  #   full_datetimes
  # end

  def generate_datetimes(start_time, end_time, interval, num_weeks, slot_duration, excluded_fixed_weekly_slots, user = nil)
    Time.zone = 'Europe/Paris'
    full_datetimes = []
    weekly_datetimes = []
    daily_datetimes = []
    current_time = Time.zone.now

    user ||= current_user
    given_days_of_week = user.days_of_week
    converted_available_slots = convert_available_slots(user.availables)
    availability_weeks = user.availability_weeks

    week_num = 0
    weeks_generated = 0
    loop do
      formatted_current_week_start = (current_time.beginning_of_week + week_num.weeks).strftime("%a, %d %b %Y")
      availability_week = availability_weeks.find { |aw| aw.week_start.strftime("%a, %d %b %Y") == formatted_current_week_start }

      if availability_week && !availability_week.week_enabled
        full_datetimes << []
      else
        given_days_of_week.each do |day|
          next if availability_week && !availability_week["available_#{day.downcase}"]

          first_day_of_week = current_time.beginning_of_week + week_num.weeks
          day_offset = (Date.parse(day).wday - first_day_of_week.wday) % 7
          target_day = first_day_of_week + day_offset.days

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
            daily_datetimes << slot unless excluded || slot.to_date < current_time.to_date
            slot += interval.minutes
          end

          converted_available_slots.each do |available_slot|
            if available_slot.to_date == target_day.to_date && available_slot.to_date >= current_time.to_date && !daily_datetimes.include?(available_slot)
              daily_datetimes << available_slot
            end
          end

          daily_datetimes.sort!
          sort_bookings(daily_datetimes, slot_duration, user)

          weekly_datetimes << daily_datetimes unless daily_datetimes.empty?
          daily_datetimes = []
        end
      end

      full_datetimes << weekly_datetimes

      weeks_generated += 1 unless weekly_datetimes.empty?
      break if weeks_generated == num_weeks

      week_num += 1
      weekly_datetimes = []
    end

    full_datetimes
  end




  # def generate_day_datetimes(start_time, end_time, interval, slot_duration, excluded_fixed_weekly_slots, user = nil, target_date)
  #   Time.zone = 'Europe/Paris'
  #   daily_datetimes = []
  #   current_time = Time.zone.now

  #   user ||= current_user
  #   converted_available_slots = convert_available_slots(user.availables)

  #   target_day = Date.parse(target_date)

  #   slot = Time.zone.local(target_day.year, target_day.month, target_day.day, start_time.hour, start_time.min, start_time.sec)
  #   while slot <= Time.zone.local(target_day.year, target_day.month, target_day.day, end_time.hour, end_time.min, end_time.sec)
  #     excluded = false
  #     excluded_fixed_weekly_slots.each do |fw_slot|
  #       fw_day_of_week = fw_slot[0]
  #       fw_start_time = Time.zone.parse(fw_slot[1])
  #       fw_end_time = Time.zone.parse(fw_slot[2])
  #       if slot.strftime("%A") == fw_day_of_week && slot >= Time.zone.local(slot.year, slot.month, slot.day, fw_start_time.hour, fw_start_time.min, 0) && slot + slot_duration.minutes <= Time.zone.local(slot.year, slot.month, slot.day, fw_end_time.hour, fw_end_time.min, 0)
  #         excluded = true
  #         break
  #       end
  #     end
  #     daily_datetimes << slot unless excluded || slot.to_date < current_time.to_date
  #     slot += interval.minutes
  #   end

  #   converted_available_slots.each do |available_slot|
  #     if available_slot.to_date == target_day.to_date && available_slot.to_date >= current_time.to_date && !daily_datetimes.include?(available_slot)
  #       daily_datetimes << available_slot
  #     end
  #   end

  #   daily_datetimes.sort!
  #   sort_bookings(daily_datetimes, slot_duration, user)

  #   daily_datetimes
  # end

  def generate_day_datetimes(start_time, end_time, interval, slot_duration, excluded_fixed_weekly_slots, user = nil, target_date)
    Time.zone = 'Europe/Paris'
    daily_datetimes = []
    current_time = Time.zone.now

    user ||= current_user
    converted_available_slots = convert_available_slots(user.availables)

    target_day = Date.parse(target_date)

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
      daily_datetimes << slot unless excluded || slot.to_date < current_time.to_date
      slot += interval.minutes
    end

    converted_available_slots.each do |available_slot|
      if available_slot.to_date == target_day.to_date && available_slot.to_date >= current_time.to_date && !daily_datetimes.include?(available_slot)
        daily_datetimes << available_slot
      end
    end

    daily_datetimes.sort!
    sort_bookings(daily_datetimes, slot_duration, user)

    daily_datetimes
  end


  def convert_available_slots(available_slots)
    converted_slots = []
    available_slots.each do |slot|
      slot_start = slot.start_time
      converted_slots << slot_start
    end
    converted_slots
  end


  def sort_bookings(daily_datetimes, slot_duration, user)
    @user_bookings = user.bookings.upcoming_all
    overlapping_slots = []
    daily_datetimes.each do |slot|
      slot_end = slot + (slot_duration + user.break_time).minutes
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
