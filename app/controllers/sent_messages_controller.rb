class SentMessagesController < ApplicationController
  before_action :set_sent_message, only: [:show, :edit, :update, :destroy]

  # GET /sent_messages
  # GET /sent_messages.json
  def index
    @sent_messages = SentMessage.all
  end

  # GET /sent_messages/1
  # GET /sent_messages/1.json
  def show
  end

  # GET /sent_messages/new
  def new
    @sent_message = SentMessage.new
  end

  # GET /sent_messages/1/edit
  def edit
  end

  # POST /sent_messages
  # POST /sent_messages.json
  def create
    @sent_message = SentMessage.new(sent_message_params)

    respond_to do |format|
      if @sent_message.save
        format.html { redirect_to @sent_message, notice: 'Sent message was successfully created.' }
        format.json { render :show, status: :created, location: @sent_message }
      else
        format.html { render :new }
        format.json { render json: @sent_message.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /sent_messages/1
  # PATCH/PUT /sent_messages/1.json
  def update
    respond_to do |format|
      if @sent_message.update(sent_message_params)
        format.html { redirect_to @sent_message, notice: 'Sent message was successfully updated.' }
        format.json { render :show, status: :ok, location: @sent_message }
      else
        format.html { render :edit }
        format.json { render json: @sent_message.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sent_messages/1
  # DELETE /sent_messages/1.json
  def destroy
    @sent_message.destroy
    respond_to do |format|
      format.html { redirect_to sent_messages_url, notice: 'Sent message was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_sent_message
      @sent_message = SentMessage.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def sent_message_params
      params.require(:sent_message).permit(:type, :brand_id, :user_id, :article_id, :show_id, :sent_at, :text)
    end
end
