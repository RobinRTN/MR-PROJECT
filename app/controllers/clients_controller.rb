class ClientsController < ApplicationController

  before_action :set_client, only: :update

  def new
    @client = Client.new
  end

  def index
    clients = current_user.clients
    @clients = clients.order(:full_name)
    groups = current_user.groups
    @groups = groups.order(:name)
  end

  def show
    @client = Client.find(params[:id])
    @all_bookings = @client.bookings.order(start_time: :desc)
    unless params[:format].nil?
      received_data = params[:format].split("/")
      @previous_page = received_data[0]
      @booking_id = received_data[1]
    end
  end

  def create
    @client = Client.new(client_params)
    @client.user_id = current_user.id
    if @client.save
      redirect_to clients_path
    else
      flash.alert = "Tous les champs doivent être complétés 🛠️"
    end
  end

  def update
    @client.update(client_params)
    redirect_to clients_path
  end

  private

  def client_params
    params.require(:client).permit(:first_name, :last_name, :email, :photo)
  end

  def set_client
    @client = Client.find(params[:id])
  end
end
