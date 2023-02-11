class ClientsController < ApplicationController

  before_action :set_client, only: :update

  def new
    @client = Client.new
  end

  def index
    @clients = Client.where(user_id: current_user.id)
  end

  def show
    @client = Client.find(params[:id])
  end

  def create
    @client = Client.new(client_params)
    @client.user_id = current_user.id
    if @client.save
      redirect_to "/users/sign_up"
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
    params.require(:client).permit(:first_name, :last_name, :email)
  end

  def set_client
    @client = Client.find(params[:id])
  end
end
