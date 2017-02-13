include Facebook::Messenger

Facebook::Messenger::Subscriptions.subscribe(access_token: ENV['ACCESS_TOKEN'])

Bot.on :message do |message|
  puts "Received '#{message.inspect}' from #{message.sender}"

  user = User.where(fbid: message.sender['id']).first_or_create
  puts "User: #{user.id} - #{user.fbid}"

  @conversation = Conversation.create_with(started_at: Time.now).find_or_create_by(user: user)
  puts "Convo: #{@conversation.id}"

  msg = Message.create(mid: message.messaging['message']['mid'], senderid: message.messaging['sender']['id'], seq: message.messaging['message']['seq'], sent_at: message.messaging['timestamp'], text: message.text)
  puts "Stored a record of this message: #{msg.id}"

  case message.text
  when /gogo/i
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

  when /designers|settings/i
    text = user.designers_following_text
    message.reply(text: text)
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
    puts text
  when /our picks|highlights|best/i
    text = Content.find_by_label("our_picks").body
    message.reply(text: text)
  when /help/i
    text = Content.find_by_label("help").body
    message.reply(text: text)
  else
    if brand = Brand.where(title: message.text.downcase).first
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

      # Failed finding possible set answers for the question about brands
      elsif brand_question
        message.reply(text: brand_question.text).body
      # Failed finding the brand question at all, fallback to content
      else
        message.reply(text: Content.find_by_label("brand_question").body)
      end

      # Failed finding a match for the brand entered
    else
      text = Content.find_by_label("unrecognised").body
      message.reply(text: "#{text} '#{message.text}'")
    end
  end
end
  
Bot.on :postback do |postback|
  puts "Received postback #{postback.inspect} from #{postback.sender}"

  user = User.where(fbid: postback.sender['id']).first_or_create
  puts "User: #{user.id} - #{user.fbid}"

  @conversation = Conversation.create_with(started_at: Time.now).find_or_create_by(user: user)
  puts "Convo: #{@conversation.id}"

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
            text = "The runway show for #{brand.title} "
            text += "is" if show.upcoming?
            text += "was" if show.past?
            text += " at #{show.date_time.to_formatted_s(:long_ordinal)}"
            text += " in #{show.location.title}."
            postback.reply(text: text)
          end
        else
          postback.reply(text: Content.find_by_label("no_shows_for_brand").body)
        end
      end
      if answer.action == "send_latest_news"
        # find show information and send it
        brand.articles.each do |article|
          postback.reply(
            attachment: {
              type: 'template',
              payload: {
                template_type: 'generic',
                elements: [
                  {
                    title: article.title,
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
        end
      end

    else
      postback.reply(text: Content.find_by_label("unrecognised").body)
    end

  when /^answer:/
    # parse the payload for answer id
    answer_id = postback.payload.split(":").last

    # look up the value for this answer to the question
    @answer = PossibleAnswer.find(answer_id)

    # echo back (for testing purposes only - TODO: remove this)
    text = "You answered: #{@answer.value}"
    postback.reply(text: text)

    begin
      appropriate_response = @answer.appropriate_response
      postback.reply(text: appropriate_response.text)
    rescue => e
      puts e
      puts "failed finding an appropriate_response for answer ##{@answer.id}"
    end

    if @answer.category == "runway_shows" && @answer.action == "send_latest_shows"
      # respond with the most recent shows
      puts "*** SEND LATEST SHOWS ***"
      
    elsif @answer.category == "runway_shows" && @answer.action == "send_vogue_picks_shows"
      # respond with vogue picks of the shows
      puts "*** SEND VOGUE PICKS ***"


    elsif @answer.question.category == "top_stories" && @answer.action == "subscribe_to_top_stories"
      # subscribe to top stories
      puts "*** SUBSCRIBE TO TOP STORIES ***"
      user.top_stories_subscription = true
      user.save!
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
    elsif @next_question
      postback.reply(text: @next_question.text)
    end

  when /my-designers|settings|designers|prefs|preferences/i
    text = user.designers_following_text
    postback.reply(text: text)

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

  when /OUR_PICKS|highlights/i
    text = Content.find_by_label("our_picks").body
    text = "Our picks of today's runway shows are TBD..."
    postback.reply(text: text)
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
  when /help/i
    text = Content.find_by_label("help").body
    postback.reply(text: text)
  else
    puts postback.payload
    text = "Unknown postback: #{postback.payload}"
    postback.reply(text: text)
  end

  @conversation.update(last_message_sent_at: Time.now)
end

Bot.on :delivery do |delivery|
  puts "Delivered message(s) #{delivery.ids}"
end


Bot.on :read do |r|
  puts "Message read: #{r}"
end
