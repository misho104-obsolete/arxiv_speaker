arxiv_speaker
=============
Source codes for arXiv@Twitter bots, which daily tweet the new submissions on arXiv.
Written for Ruby1.9 + RubyGems.

See http://en.misho-web.com/phys/hep_tools.html#arxiv_speaker for details.


###Example
 * http://twitter.com/hep_ph
 * http://twitter.com/hep_th
 * http://twitter.com/hep_ex
 * http://twitter.com/hep_lat

###Requirement
 Ruby 1.9+ and gems (htmlentities, nokogiri, oauth)

###Installation
  First try with the default setting, i.e., rename "arxiv_config.yml.default" to "arxiv_config.yml" and execute "arxiv.rb".
  Then perhaps the "new" articles on arXiv hep-ph, hep-th, hep-ex, and hep-lat are displayed on terminal.

  Note that, here, "arxiv_latest.yml" is generated.
  In this file the latest arXiv IDs in the previous execution are stored; duplecated tweets are suppressed by this information.
  Therefore, if you execute "arxiv.rb" again, you will see that this script tries to find new articles several times and finally concludes "there are no new article today".
  If you delete "arxiv_latest.yml", then the new article on the day are displayed again.

  You can change the categories with editing the config file. 
  Note that :name and :url are case sensitives.

  If you want to tweet the results, you have to get oauth keys and write them in the configure file (See Google for detail!).
  Finally, you release the safety catch ( :go_ahead in the configure file), and the bots will tweet arXiv updates.

  You should run this script once in a day (but not in holidays).
  Probably 00:00 UTC to 01:00 UTC is the best for the execution. See the first comment in "arxiv.rb" for details.
  Note that this script may need more than two hours to complete a daily run.

  

###Feedback
 * http://twitter.com/misho

