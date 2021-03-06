Meteor.methods
  slideLeft: (slide) ->
    check slide, Object
    unless Roles.userIsInRole(@userId, [ 'teacher' ], 'all')
      throw new Meteor.Error(403, 'Unauthorized')
    prevSlideNumber = slide.currentSlideNumber - 1
    unless prevSlideNumber < 1
      Slides.update({ lang: slide.lang }, {
        $set:
          currentSlideNumber: prevSlideNumber
          currentSlideTemplate: 'skSlide' + prevSlideNumber
      })

  slideRight: (slide) ->
    check slide, Object
    unless Roles.userIsInRole(@userId, [ 'teacher' ], 'all')
      throw new Meteor.Error(403, 'Unauthorized')
    nextSlideNumber = slide.currentSlideNumber + 1
    Slides.update({ lang: slide.lang }, {
      $set:
        currentSlideNumber: nextSlideNumber
        currentSlideTemplate: 'skSlide' + nextSlideNumber
    })

  setSlideNumber: (slideNumber) ->
    check slideNumber, Number
    unless Roles.userIsInRole(@userId, [ 'teacher' ], 'all')
      throw new Meteor.Error(403, 'Unauthorized')
    Slides.update({ lang: 'sk' }, {
      $set:
        currentSlideNumber: slideNumber
        currentSlideTemplate: 'skSlide' + slideNumber
    })

  saveHtmlCode: (code) ->
    check(code, String)
    unless Roles.userIsInRole(@userId, [ 'teacher' ], 'all')
      throw new Meteor.Error(403, 'Unauthorized')
    existing = Code.findOne({ type: 'html' })
    if existing
      Code.update({ type: 'html' }, {
        $set:
          code: code
      })
    else
      Code.insert
        type: 'html'
        code: code

  saveJsCode: (code) ->
    check(code, String)
    unless Roles.userIsInRole(@userId, [ 'teacher' ], 'all')
      throw new Meteor.Error(403, 'Unauthorized')
    existing = Code.findOne({ type: 'js' })
    if existing
      Code.update({ type: 'js' }, {
        $set:
          code: code
      })
    else
      Code.insert({
        type: 'js'
        code: code
      })

  saveNeedHelpComment: (opts) ->
    check(opts.needHelpId, String)
    check(opts.lesson, Object)
    check(opts.sendEmail, Match.Optional Boolean)
    check(opts.msg, String)
    check(opts.url, String)
    check(opts.lang, String)
    unless @userId
      throw new Meteor.Error(401, 'To perform this action, you have to be logged in')

    user = Meteor.users.findOne(@userId)
    if Meteor.isServer
      commentsCount = NeedHelpComments.find
        needHelpId: opts.needHelpId
      .count()

      needHelp = NeedHelp.findOne opts.needHelpId
      elfoslavUser = Meteor.users.findOne({ username: 'elfoslav' })
      if needHelp.username != user.username
        App.insertMessage
          senderId: elfoslavUser._id
          senderUsername: elfoslavUser.username
          receiverId: needHelp.user?._id
          receiverUsername: needHelp.user?.username
          needHelpId: needHelp._id
          text: """
            (auto generated message) Hello, you asked for help and someone answered it.
            Read the answer here: #{Meteor.absoluteUrl()}help/#{needHelp._id}
          """

      if opts.sendEmail
        console.log 'sending need help email to', needHelp.user.emails?[0]?.address
        mailBody = """
          You asked for help and #{user.username} is trying to help you:
          <a href=\"#{opts.url}\">#{opts.url}</a>
        """
        if needHelp.user.emails?[0]?.address != user?.emails?[0]?.address
          @unblock()
          Email.send
            from: user?.emails?[0]?.address || 'info@codermania.com'
            to: needHelp.user.emails?[0].address
            subject: "CoderMania - New comment in need help #{opts.lesson.title}"
            html: mailBody

    NeedHelpComments.insert
      needHelpId: opts.needHelpId
      userId: user?._id
      username: user?.username
      text: opts.msg
      timestamp: Date.now()
      lang: opts.lang
      readBy: []

  markNeedHelpSolved: (needHelpId) ->
    check needHelpId, String
    unless Roles.userIsInRole(@userId, [ 'teacher' ], 'all')
      throw new Meteor.Error(403, 'Unauthorized')
    NeedHelp.update needHelpId,
      $set:
        solved: true

  markNeedHelpUnsolved: (needHelpId) ->
    check needHelpId, String
    unless Roles.userIsInRole(@userId, [ 'teacher' ], 'all')
      throw new Meteor.Error(403, 'Unauthorized')
    NeedHelp.update needHelpId,
      $set:
        solved: false

  joinStudyGroup: (data) ->
    check data,
      studyGroupId: String

    unless @userId
      throw new Meteor.Error(401, 'To perform this action, you have to be logged in')

    studyGroup = StudyGroups.findOne
      _id: data.studyGroupId
      userIds: $in: [ @userId ]

    if studyGroup
      throw new Meteor.Error('already-joined', 'You already are in this group')

    StudyGroups.update data.studyGroupId,
      $push: userIds: @userId

  leaveStudyGroup: (data) ->
    check data,
      studyGroupId: String

    unless @userId
      throw new Meteor.Error(401, 'To perform this action, you have to be logged in')

    StudyGroups.update data.studyGroupId,
      $pull: userIds: @userId

  saveStudyGroupMessage: (data) ->
    check data,
      studyGroupId: String
      text: String
    unless @userId
      throw new Meteor.Error(401, 'To perform this action, you have to be logged in')

    StudyGroupMessages.insert
      studyGroupId: data.studyGroupId
      text: data.text
      userId: @userId
      timestamp: Date.now()
      isReadBy: [ @userId ]

  updateUserSettings: (data) ->
    check data,
      studyGroupNotifications: Match.Optional String
    data.userId = @userId
    Meteor.users.update
      _id: @userId
    ,
      $set:
        'settings.emailNotifications.studyGroupNotifications': data.studyGroupNotifications
