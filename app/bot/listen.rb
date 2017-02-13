include Facebook::Messenger

Facebook::Messenger::Subscriptions.subscribe(access_token: ENV['ACCESS_TOKEN'])

Bot.on :message do |message|
  puts "Received '#{message.inspect}' from #{message.sender}"

  sent_message = User.create_with_sent_message(message)
  user = sent_message.user

  @conversation = user.conversation
  puts "Convo: #{@conversation.id}"

  Message.log_it(message)

  case message.text
  when /start/i
    @question = Question.starting
    text = @question.text
    buttons = @question.possible_answers.map do |pa|
      { type: 'postback', title: pa.value, payload: "answer:#{pa.id}" }
    end
    message.reply(
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: text,
          buttons: buttons
        }
      }
    )
    sent_message.update!(text: text, sent_at: Time.now)

  when /designers|settings/i
    text = user.designers_following_text
    message.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)
  when /latest shows|upcoming shows|upcoming/i
    if Show.upcoming.any?
      text = Content.find_by_label("upcoming_shows").body
      next_three = Show.upcoming.order("date_time ASC").limit(3)
      text += next_three.map do |show|
        "#{show.title} at #{show.date_time.to_formatted_s(:long_ordinal)}"
      end.join(', ')
      puts text
      message.reply(text: text)
    else
      text = Content.find_by_label("no_upcoming_shows").body
      message.reply(text: text)
    end
    sent_message.update!(text: text, sent_at: Time.now)
    puts text
  when /our picks|highlights|best/i
    text = Content.find_by_label("our_picks").body
    message.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)
  when /help/i
    text = Content.find_by_label("help").body
    message.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)
  else
    if brand = Brand.where("title ilike ?", message.text.downcase).first
      puts "Found matching brand: #{brand.id} - #{brand.title}"
      # TODO: add a followup question
      brand_question = Question.where(category: "designers").first
      if brand_question && brand_question.possible_answers.any?
        buttons = brand_question.possible_answers.map do |pa|
          { type: 'postback', title: pa.value, payload: "brand:#{brand.id}:answer:#{pa.id}" }
        end
        message.reply(
          attachment: {
            type: 'template',
            payload: {
              template_type: 'button',
              text: brand_question.text,
              buttons: buttons
            }
          }
        )
        sent_message.update!(text: brand_question.text, sent_at: Time.now)

      # Failed finding possible set answers for the question about brands
      elsif brand_question
        message.reply(text: brand_question.text).body
        sent_message.update!(text: brand_question.text, sent_at: Time.now)
      # Failed finding the brand question at all, fallback to content
      else
        text = Content.find_by_label("brand_question").body
        message.reply(text: text)
        sent_message.update!(text: text, sent_at: Time.now)
      end

      # Failed finding a match for the brand entered
    else
      puts "Failed finding a matching brand for the text '#{message.text.downcase}'"
      text = Content.find_by_label("unrecognised").body
      message.reply(text: "#{text} '#{message.text}'")
      sent_message.update!(text: text, sent_at: Time.now)
    end
  end
end
  
Bot.on :postback do |postback|
  puts "Received postback #{postback.inspect} from #{postback.sender}"

  sent_message = User.create_with_sent_message(postback)
  user = sent_message.user

  @conversation = user.conversation
  puts "Convo: #{@conversation.id}"

  Message.log_it(postback)

  case postback.payload

  when /^brand:/
    # parse the payload for brand and answer id
    brand_id = postback.payload.split(":")[1]
    answer_id = postback.payload.split(":").last
    brand = Brand.find(brand_id)
    answer = PossibleAnswer.find(answer_id)
    if brand && answer
      puts "found brand: #{brand.title}"
      puts "found answer: #{answer.action} #{answer.id}"
      if answer.action == "send_show_info"
        # find show information and send it
        if brand.shows.any?
          brand.shows.each do |show|
            show.send_message(user)
          end
        else
          text = Content.find_by_label("no_shows_for_brand").body
          postback.reply(text: text)
          sent_message.update!(text: text, sent_at: Time.now)
        end
      end
      if answer.action == "send_latest_news"
        brand.articles.limit(2).each do |article|
          postback.reply(
            attachment: {
              type: 'template',
              payload: {
                template_type: 'generic',
                elements: [
                  {
                    title: article.title,
                    image_url: article.image_url,
                    default_action: {
                      type: "web_url",
                      url: article.url
                    },
                    buttons:[
                      {
                        type: "web_url",
                        url: article.url,
                        title: "View the Article"
                      }
                    ]      
                  }
                ]
              }
            })
          sent_message.update!(article: article, text: article.title, sent_at: Time.now)
        end
      end

    else
      text = Content.find_by_label("unrecognised").body
      postback.reply(text: text)
      sent_message.update!(text: text, sent_at: Time.now)
    end

  when /^answer:/
    # parse the payload for answer id
    answer_id = postback.payload.split(":").last

    # look up the value for this answer to the question
    @answer = PossibleAnswer.find(answer_id)

    begin
      appropriate_response = @answer.appropriate_response
      postback.reply(text: appropriate_response.text)
      sent_message.update!(text: appropriate_response.text, sent_at: Time.now)
    rescue => e
      puts e
      puts "failed finding an appropriate_response for answer ##{@answer.id}"
    end

    if @answer.category == "runway_shows" && @answer.action == "send_latest_shows"
      # respond with the most recent shows
      puts "*** SEND LATEST SHOWS ***"
      if Show.past.any?
        text = Content.find_by_label("upcoming_shows").body
        shows = Show.past.order("date_time DESC").limit(3)
        user.deliver_message_for(shows, "View the Show")
      else
        text = Content.find_by_label("no_upcoming_shows").body
        message.reply(text: text)
      end
      sent_message.update!(text: text, sent_at: Time.now)
      puts text

    elsif @answer.category == "runway_shows" && @answer.action == "send_vogue_picks_shows"
      # respond with vogue picks of the shows
      puts "*** SEND VOGUE PICKS ***"


    elsif @answer.question.category == "top_stories" && @answer.action == "subscribe_to_top_stories"
      # subscribe to top stories
      puts "*** SUBSCRIBE TO TOP STORIES ***"
      user.top_stories_subscription = true
      user.save!

      user.send_top_stories(4)

    end

    @next_question = if appropriate_response.next_question.present?
                       puts " Found the next question for response ##{appropriate_response.id}: #{appropriate_response.next_question.id}"
                       appropriate_response.next_question
                     else
                       puts " Using the next question for answer ##{@answer.id}: #{@answer.question.next.id}"
                       # lookup the next question
                       @answer.question.next
                     end

    if @next_question && @next_question.possible_answers.any?
      buttons = @next_question.possible_answers.map do |pa|
        { type: 'postback', title: pa.value, payload: "answer:#{pa.id}" }
      end
      postback.reply(
        attachment: {
          type: 'template',
          payload: {
            template_type: 'button',
            text: @next_question.text,
            buttons: buttons
          }
        }
      )
      sent_message.update!(text: @next_question.text, sent_at: Time.now)
    elsif @next_question
      postback.reply(text: @next_question.text)
      sent_message.update!(text: @next_question.text, sent_at: Time.now)
    end

  when /my-designers|settings|designers|prefs|preferences/i
    text = user.designers_following_text
    postback.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)

  when 'get_started'
    @question = Question.starting
    text = @question.text
    buttons = @question.possible_answers.map do |pa|
      { type: 'postback', title: pa.value, payload: "answer:#{pa.id}" }
    end
    postback.reply(
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: text,
          buttons: buttons
        }
      }
    )
    sent_message.update!(text: text, sent_at: Time.now)

  when /OUR_PICKS|highlights/i
    text = Content.find_by_label("our_picks").body
    postback.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)

  when /upcoming/i
    if Show.upcoming.any?
      text = Content.find_by_label("upcoming_shows").body + " "
      next_three = Show.upcoming.order("date_time ASC").limit(3)
      text += next_three.map do |show|
        "#{show.title} at #{show.date_time.to_formatted_s(:long_ordinal)}"
      end.join(', ')
      puts text
    else
      text = Content.find_by_label("no_upcoming_shows").body
    end
    postback.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)
  when /help/i
    text = Content.find_by_label("help").body
    postback.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)
  else
    puts postback.payload
    text = "Unknown postback: #{postback.payload}"
    postback.reply(text: text)
    sent_message.update!(text: text, sent_at: Time.now)
  end

  @conversation.update(last_message_sent_at: Time.now)
end

Bot.on :delivery do |delivery|
  puts "Delivered message(s) #{delivery.ids}"
end


Bot.on :read do |r|
  puts "Message read: #{r}"
end
