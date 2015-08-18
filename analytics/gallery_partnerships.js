//This tracks the gallery application form on the gallery partnerships page,
//and allows us to track gallery behavior by the tier subsequenly assigned
// in Salesforce by the GP team.

if (location.pathname.match('/gallery-partnerships')) {

  analytics.page('Gallery Partnerships');
  // Explicit page track to snowplow to send the session id for joining
  // salesforce and snowplow later.
  snowplow('trackStructEvent', 'partner_application', 'page_view', sd.SESSION_ID);

  analytics.trackForm(
    $('.js-gallery-partnerships-apply-form')[0],
    '/gallery-partnerships CTA',
    {
      session_id: sd.SESSION_ID,
      user_id: sd.CURRENT_USER && sd.CURRENT_USER.id,
      test_copy: sd.PARTNER_APPLICATION_COPY 
    }
  );

  $('.partnerships-nav-link.internal').click(function(e){
    var section = $(e.currentTarget).attr('data-section')
    analytics.track('Clicked nav link on gallery partnerships',
      {section: section})
  })

  $('.partnerships-nav-apply-link').click(function(e){
    analytics.track('Clicked nav apply on gallery partnerships')
  })

  $('.js-gallery-partnerships-apply-submit').click(function(e){
    analytics.track('Clicked bottom apply on gallery partnerships', {
      test_copy: sd.PARTNER_APPLICATION_COPY
    })
  })
}
