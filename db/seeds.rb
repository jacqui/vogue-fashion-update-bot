# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Content.delete_all
Response.delete_all
PossibleAnswer.delete_all
Question.delete_all

puts "Setting up database with initial content..."

top_stories = Question.create!(sort_order: 1, text: "Would you like to get the top stories (twice/day)?", type: "yes_no", category: "top_stories")
ts_yes = top_stories.possible_answers.create!(value: "Yes", sort_order: 1, category: "top_stories", action: "subscribe_to_top_stories")
ts_no = top_stories.possible_answers.create!(value: "No", sort_order: 2, category: "top_stories", action: "skip_to_next_question")
ts_yes.create_response!(text: "Here are the top 4 stories:", category: "top_stories", quantity: 4, question: top_stories)
ts_no.create_response!(text: "Ok.", category: "text", question: top_stories)

puts " * question ##{top_stories.id} '#{top_stories.text}' order ##{top_stories.sort_order} with #{top_stories.possible_answers.size} possible answers"

runway_shows = Question.create!(sort_order: 2, text: "Want to see some runway shows?", type: "choices_provided", category: "runway_shows")
rs_latest = runway_shows.possible_answers.create!(value: "The Latest", sort_order: 1, category: "runway_shows", action: "send_latest_shows")
rs_vogue = runway_shows.possible_answers.create!(value: "Vogue Picks", sort_order: 2, category: "runway_shows", action: "send_vogue_picks_shows")
rs_no = runway_shows.possible_answers.create!(value: "Not now.", sort_order: 3, category: "runway_shows", action: "skip_to_next_question")

rs_latest.create_response!(text: "Here are the latest shows:", category: "runway_shows", quantity: 2, question: runway_shows)
rs_vogue.create_response!(text: "These are our picks of the runway shows:", category: "runway_shows", quantity: 2, question: runway_shows)

#designer_prompt = Question.create!(sort_order: 3, text: "", type: "choices_provided_or_free", followup: true, category: "runway_shows")
#designer_prompt.possible_answers.create!(value: "Burberry", sort_order: 1, brand: Brand.where(title: "Burberry").first, category: "runway_shows")
#designer_prompt.possible_answers.create!(value: "Gucci", sort_order: 2, brand: Brand.where(title: "Gucci").first, category: "runway_shows")
#designer_prompt.possible_answers.create!(value: "Prada", sort_order: 3, brand: Brand.where(title: "Prada").first, category: "runway_shows")
#rs_some.create_response!(text: "Ok, which designers? ", category: "text", question: runway_shows, next_question: designer_prompt)

#designer_prompt.create_response!(text: "Designer show information goes here.", category: "runway_shows", question: designer_prompt) # TODO: implement logic to display a past show if exists, or send one later/subscribe


puts " * question ##{runway_shows.id} '#{runway_shows.text}' order ##{runway_shows.sort_order} with #{runway_shows.possible_answers.size} possible answers"

brand_action_q = Question.create!(sort_order: 3, text: "What would you like to do?", type: "choices_provided", category: "designers", followup: true)
brand_action_q.possible_answers.create!(sort_order: 1, value: "Show info", category: "designers", action: "send_show_info")
brand_action_q.possible_answers.create!(sort_order: 2, value: "Latest news", category: "designers", action: "send_latest_news")

designer_news = Question.create!(sort_order: 4, text: "What designers are you most interested in?", type: "free", category: "designers")
rs_no.create_response!(text: "That's cool.", category: "text", question: runway_shows, next_question: designer_news)
# designer_news.create_response!(text: "", category: "text", question: designer_news)
#puts " * question ##{designer_news.id} '#{designer_news.text}' order ##{designer_news.sort_order} with #{designer_news.possible_answers.size} possible answers"

Content.create(title: "Greeting", label: "greeting", body: "Chat with Vogue for all the latest fashion news straight from the runway.")
Content.create(title: "Get Started", label: "get_started", body: "Get started by telling me what designers you like.")
Content.create(title: "Help", label: "help", body: "Get started by telling me what designers you like.")
Content.create(title: "Following List", label: "following_list", body: "You're following these designers:")
Content.create(title: "Already Following", label: "following_already", body: "You're already following")
Content.create(title: "Now Following", label: "following_now", body: "You're now following")
Content.create(title: "Following Nobody", label: "following_none", body: "You're not following any designers yet - type a name to start!")
Content.create(title: "Upcoming Shows", label: "upcoming_shows", body: "These shows are coming up next:")
Content.create(title: "No Upcoming Shows", label: "no_upcoming_shows", body: "Oh no! There are no more shows coming up next :(")
Content.create(title: "Our Picks", label: "our_picks", body: "Our favourite shows of the day: the Calvin Klein Collection.")
Content.create(title: "Unrecognised", label: "unrecognised", body: "Sorry, I don't understand")
Content.create(title: "Brand Actions", label: "brand_actions", body: "What would you like to know about that designer? I know about 'shows' and 'news'.")
Content.create(title: "No shows For Brand", label: "no_shows_for_brand", body: "There are no shows for that brand.")

puts " * created #{Content.count} pieces of other content"
