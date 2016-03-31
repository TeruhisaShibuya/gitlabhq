class @AwardsHandler
  constructor: ->
    @aliases = emojiAliases()

    $(document).on "click", ".js-add-award", (event) =>
      event.stopPropagation()
      event.preventDefault()

      @showEmojiMenu $(event.currentTarget)

    $("html").on 'click', (event) ->
      if !$(event.target).closest(".emoji-menu").length
        if $(".emoji-menu").is(":visible")
          $(".emoji-menu").removeClass "is-visible"

    $(document)
      .off "click", ".js-emoji-btn"
      .on "click", ".js-emoji-btn", @handleClick

  handleClick: (e) =>
    e.preventDefault()
    $emojiBtn = $(e.currentTarget)
    awardUrl = $emojiBtn.closest('.js-votes-block').data 'award-url'
    emoji = $emojiBtn
      .find(".icon")
      .data "emoji"
    @addAward awardUrl, emoji

  showEmojiMenu: ($addBtn) ->
    if $(".emoji-menu").length
      $holder = $addBtn.closest('.js-award-holder')

      if $holder.find('.emoji-menu').length is 0
        $(".emoji-menu").detach().appendTo $holder

      if $(".emoji-menu").is ".is-visible"
        $(".emoji-menu").removeClass "is-visible"
        $("#emoji_search").blur()
      else
        $(".emoji-menu").addClass "is-visible"
        $("#emoji_search").focus()
    else
      $addBtn.addClass "is-loading"
      $.get $addBtn.data('award-menu-url'), (response) =>
        $addBtn.removeClass "is-loading"
        $addBtn.closest('.js-award-holder').append response
        @renderFrequentlyUsedBlock()
        setTimeout =>
          $(".emoji-menu").addClass "is-visible"
          $("#emoji_search").focus()
          @setupSearch()
        , 200

  addAward: (awardUrl, emoji) ->
    emoji = @normilizeEmojiName(emoji)
    @postEmoji awardUrl, emoji, =>
      @addAwardToEmojiBar(emoji)

    $(".emoji-menu").removeClass "is-visible"

  addAwardToEmojiBar: (emoji) ->
    @addEmojiToFrequentlyUsedList(emoji)

    emoji = @normilizeEmojiName(emoji)
    if @exist(emoji)
      if @isActive(emoji)
        @decrementCounter(emoji)
      else
        counter = @findEmojiIcon(emoji).siblings(".js-counter")
        counter.text(parseInt(counter.text()) + 1)
        counter.parent().addClass("active")
        @addMeToUserList(emoji)
    else
      @createEmoji(emoji)

  exist: (emoji) ->
    @findEmojiIcon(emoji).length > 0

  isActive: (emoji) ->
    @findEmojiIcon(emoji).parent().hasClass("active")

  decrementCounter: (emoji) ->
    counter = @findEmojiIcon(emoji).siblings(".js-counter")
    emojiIcon = counter.parent()
    if parseInt(counter.text()) > 1
      counter.text(parseInt(counter.text()) - 1)
      emojiIcon.removeClass("active")
      @removeMeFromUserList(emoji)
    else if emoji == "thumbsup" || emoji == "thumbsdown"
      emojiIcon.tooltip("destroy")
      counter.text(0)
      emojiIcon.removeClass("active")
      @removeMeFromUserList(emoji)
    else
      emojiIcon.tooltip("destroy")
      emojiIcon.remove()

  removeMeFromUserList: (emoji) ->
    award_block = @findEmojiIcon(emoji).parent()
    authors = award_block
      .attr("data-original-title")
      .split(", ")
    authors.splice(authors.indexOf("me"),1)
    award_block
      .closest(".js-emoji-btn")
      .attr("data-original-title", authors.join(", "))
    @resetTooltip(award_block)

  addMeToUserList: (emoji) ->
    award_block = @findEmojiIcon(emoji).parent()
    origTitle = award_block.attr("data-original-title").trim()
    users = []
    if origTitle
      users = origTitle.split(', ')
    users.push("me")
    award_block.attr("title", users.join(", "))
    @resetTooltip(award_block)

  resetTooltip: (award) ->
    award.tooltip("destroy")

    # "destroy" call is asynchronous and there is no appropriate callback on it, this is why we need to set timeout.
    setTimeout (->
      award.tooltip()
    ), 200


  createEmoji: (emoji) ->
    emojiCssClass = @resolveNameToCssClass(emoji)

    buttonHtml = "<button class='btn award-control js-emoji-btn has-tooltip active' title='me'>
      <div class='icon emoji-icon #{emojiCssClass}' data-emoji='#{emoji}'></div>
      <span class='award-control-text js-counter'>1</span>
    </button>"

    emoji_node = $(buttonHtml)
      .insertBefore(".js-award-holder:not(.js-award-action-btn)")
      .find(".emoji-icon")
      .data("emoji", emoji)
    $('.award-control').tooltip()

  resolveNameToCssClass: (emoji) ->
    emoji_icon = $(".emoji-menu-content [data-emoji='#{emoji}']")

    if emoji_icon.length > 0
      unicodeName = emoji_icon.data("unicode-name")
    else
      # Find by alias
      unicodeName = $(".emoji-menu-content [data-aliases*=':#{emoji}:']").data("unicode-name")

    "emoji-#{unicodeName}"

  postEmoji: (awardUrl, emoji, callback) ->
    $.post awardUrl, { name: emoji }, (data) ->
      if data.ok
        callback.call()

  findEmojiIcon: (emoji) ->
    $(".awards > .js-emoji-btn [data-emoji='#{emoji}']")

  scrollToAwards: ->
    $('body, html').animate({
      scrollTop: $('.awards').offset().top - 80
    }, 200)

  normilizeEmojiName: (emoji) ->
    @aliases[emoji] || emoji

  addEmojiToFrequentlyUsedList: (emoji) ->
    frequently_used_emojis = @getFrequentlyUsedEmojis()
    frequently_used_emojis.push(emoji)
    $.cookie('frequently_used_emojis', frequently_used_emojis.join(","), { expires: 365 })

  getFrequentlyUsedEmojis: ->
    frequently_used_emojis = ($.cookie('frequently_used_emojis') || "").split(",")
    _.compact(_.uniq(frequently_used_emojis))

  renderFrequentlyUsedBlock: ->
    if $.cookie('frequently_used_emojis')
      frequently_used_emojis = @getFrequentlyUsedEmojis()

      ul = $("<ul class='clearfix emoji-menu-list'>")

      for emoji in frequently_used_emojis
        $(".emoji-menu-content [data-emoji='#{emoji}']").closest("li").clone().appendTo(ul)

      $("input.emoji-search").after(ul).after($("<h5>").text("Frequently used"))

  setupSearch: ->
    $("input.emoji-search").on 'keyup', (ev) =>
      term = $(ev.target).val()

      # Clean previous search results
      $("ul.emoji-menu-search, h5.emoji-search").remove()

      if term
        # Generate a search result block
        h5 = $("<h5>").text("Search results").addClass("emoji-search")
        found_emojis = @searchEmojis(term).show()
        ul = $("<ul>").addClass("emoji-menu-list emoji-menu-search").append(found_emojis)
        $(".emoji-menu-content ul, .emoji-menu-content h5").hide()
        $(".emoji-menu-content").append(h5).append(ul)
      else
        $(".emoji-menu-content").children().show()

  searchEmojis: (term)->
    $(".emoji-menu-content [data-emoji*='#{term}']").closest("li").clone()
