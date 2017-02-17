# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Response.delete_all
PossibleAnswer.delete_all
Question.delete_all

puts "Setting up database with initial content..."

top_stories = Question.create!(sort_order: 1, text: "Welcome to the Vogue Fashion Update, {{user_first_name}}. Here are today’s top stories:", type: "free", category: "top_stories", followup: false)

sub_top_stories = Question.create!(sort_order: 2, text: "Would you like us to send you these every day at 1pm?", type: "yes_no", category: "top_stories", followup: false)

runway_shows = Question.create!(sort_order: 3, text: "Would you like to receive updates from the fashion shows?", type: "yes_no", category: "runway_shows")
runway_shows_followup = Question.create!(sort_order: 4, text: "Would you like to see highlights or all fashion shows?", type: "choices_provided", category: "runway_shows")

designers_follow = Question.create!(sort_order: 5, text: "Tell us, are there any designers you’d like regular updates on? For example:", type: "choices_provided", category: "designers")

# placeholder that determines flow of conversation after sending top stories
top_stories.create_response!(text: nil, possible_answer: nil, category: "top_stories", question: top_stories, next_question: sub_top_stories)

# Yes / No buttons for subscribe to top stories Q
ts_yes = sub_top_stories.possible_answers.create!(value: "Yes", sort_order: 1, category: "top_stories", action: "subscribe_to_top_stories")
ts_no = sub_top_stories.possible_answers.create!(value: "No", sort_order: 2, category: "top_stories", action: "ask_next_question", next_question: runway_shows)

ts_yes.create_response!(text: "Great, we’ll update you with the top stories daily.", category: "top_stories", quantity: 4, possible_answer: ts_yes, next_question: runway_shows)

# Yes / No buttons for fashion show updates
runway_yes = runway_shows.possible_answers.create!(value: "Yes", sort_order: 1, category: "runway_shows", action: "ask_next_question", next_question: runway_shows_followup)
runway_no = runway_shows.possible_answers.create!(value: "No", sort_order: 2, category: "runway_shows", action: "ask_next_question", next_question: designers_follow)

highlights_action = runway_shows_followup.possible_answers.create!(value: "Highlights", sort_order: 1, category: "runway_shows", action: "send_major_shows")
all_shows_action = runway_shows_followup.possible_answers.create!(value: "All Shows", sort_order: 2, category: "runway_shows", action: "send_latest_shows")
rsf_no = runway_shows_followup.possible_answers.create!(value: "No", sort_order: 3, category: "runway_shows", action: "ask_next_question", next_question: designers_follow)

designers_follow.possible_answers.create!(value: "JW Anderson", brand: Brand.find_by_title("JW Anderson"), action: "follow_designer")
designers_follow.possible_answers.create!(value: "Erdem", brand: Brand.find_by_title("Erdem"), action: "follow_designer")
designers_follow.possible_answers.create!(value: "Roksanda", brand: Brand.find_by_title("Roksanda"), action: "follow_designer")
designers_follow.possible_answers.create!(value: "Christopher Kane", brand: Brand.find_by_title("Christopher Kane"), action: "follow_designer")
designers_follow.possible_answers.create!(value: "Mulberry", brand: Brand.find_by_title("Mulberry"), action: "follow_designer")
designers_follow.possible_answers.create!(value: "Burberry", brand: Brand.find_by_title("Burberry"), action: "follow_designer")
designers_follow.possible_answers.create!(value: "Topshop Unique", brand: Brand.find_by_title("Topshop Unique"), action: "follow_designer")
designers_follow.possible_answers.create!(value: "No thanks", action: "send_help_text")

designers_follow.create_response!(text: "Great, we’ll update you with news alerts and show reports about ", category: "designers", question: designers_follow)

Question.all.each do |q|
  puts [q.sort_order, q.category, q.text].join(" :: ")
  q.possible_answers.each do |a|
    puts "\t" + [a.sort_order, a.category, a.action, a.value].join(" :: ")
    if a.next_question
      puts " \tNext Question: #{a.next_question.sort_order} - #{a.next_question.text}"
    end
    if a.response
      puts "\t\t" + [a.response.category, a.response.text].join(" :: ")
      if a.response.next_question
        puts " \t\tNext Question: #{a.response.next_question.sort_order} - #{a.response.next_question.text}"
      end
    end
  end
  if q.response
    puts "\t" + [q.response.category, q.response.text].join(" :: ")
    if q.response.next_question
      puts " \tNext Question: #{q.response.next_question.sort_order} - #{q.response.next_question.text}"
    end
  end
end

