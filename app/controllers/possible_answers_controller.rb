class PossibleAnswersController < ApplicationController
  before_action :set_possible_answer, only: [:show, :edit, :update, :destroy]

  # GET /possible_answers
  # GET /possible_answers.json
  def index
    @possible_answers = PossibleAnswer.all
  end

  # GET /possible_answers/1
  # GET /possible_answers/1.json
  def show
  end

  # GET /possible_answers/new
  def new
    @possible_answer = PossibleAnswer.new
  end

  # GET /possible_answers/1/edit
  def edit
  end

  # POST /possible_answers
  # POST /possible_answers.json
  def create
    @possible_answer = PossibleAnswer.new(possible_answer_params)

    respond_to do |format|
      if @possible_answer.save
        format.html { redirect_to :back, notice: 'Possible answer was successfully created.' }
        format.json { render :show, status: :created, location: @possible_answer }
      else
        format.html { render :new }
        format.json { render json: @possible_answer.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /possible_answers/1
  # PATCH/PUT /possible_answers/1.json
  def update
    respond_to do |format|
      if @possible_answer.update(possible_answer_params)
        format.html { redirect_to :back, notice: 'Possible answer was successfully updated.' }
        format.json { render :show, status: :ok, location: @possible_answer }
      else
        format.html { render :edit }
        format.json { render json: @possible_answer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /possible_answers/1
  # DELETE /possible_answers/1.json
  def destroy
    @possible_answer.destroy
    respond_to do |format|
      format.html { redirect_to possible_answers_url, notice: 'Possible answer was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_possible_answer
      @possible_answer = PossibleAnswer.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def possible_answer_params
      params.require(:possible_answer).permit(:question_id, :value, :type, :order)
    end
end
