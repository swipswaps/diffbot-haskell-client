{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Control.Exception as E
import           Data.List
import           Data.Maybe
import qualified Data.ByteString.Lazy as BL

import           Test.Framework
import           Test.Framework.Providers.HUnit
import           Test.HUnit hiding (Test, path)
import           Network.HTTP.Types.Status

import Diffbot
import Diffbot.Crawlbot

main :: IO ()
main = defaultMain tests


tests :: [Test]
tests = [ testGroup "Article"
          [ testCase "getIsJust" $ getIsJust defArticle
          , testCase "postPlainIsJust" $ postPlainIsJust defArticle
          , testCase "postHtmlIsJust" $ postHtmlIsJust defArticle
          , testCase "emptyToken" $ emptyToken defArticle
          ]
        , testGroup "FrontPage"
          [ testCase "getIsJust" (getIsJust defFrontPage)
          --  FIXME: POST request for FrontPage API
          -- , testCase "postPlainIsJust" (postPlainIsJust defFrontPage)
          -- , testCase "postHtmlIsJust" (postHtmlIsJust defFrontPage)
          , testCase "emptyToken" $ emptyToken defFrontPage
          , testCase "allIsJust" (getIsJust defFrontPage { frontPageAll = True })
          ]
        , testGroup "Image"
          [ testCase "getIsJust" (getIsJust defImage)
          , testCase "emptyToken" $ emptyToken defImage
          ]
        , testGroup "Product"
          [ testCase "getIsJust" $ getIsJust defProduct
          , testCase "emptyToken" $ emptyToken defProduct
          ]
        , testGroup "Classifier"
          [ testCase "getIsJust" $ getIsJust defClassifier
          , testCase "emptyToken" $ emptyToken defClassifier
          ]
        , testGroup "Crawlbot"
          [ testCase "crawlCommand" crawlCommand
          , testCase "crawlApiUrl" crawlApiUrl
          ]
        ]


token, url :: String
token = "1405030fcd9385c3f907472839205908"
url   = "http://blog.diffbot.com/diffbots-new-product-api-teaches-robots-to-shop-online/"


getIsJust :: Request a => a -> Assertion
getIsJust mk = do
    resp <- diffbot token url mk
    print resp
    assertBool "Nothing" $ isJust resp


postPlainIsJust :: (Request a, Post a) => a -> Assertion
postPlainIsJust mk = do
    let c   = Content TextPlain "Diffbot\8217s human wranglers are proud today to announce the release of our newest product: an API for\8230 products!"
    resp <- diffbot token url $ setContent (Just c) mk
    assertBool "Nothing" $ isJust resp


postHtmlIsJust :: (Request a, Post a) => a -> Assertion
postHtmlIsJust mk = do
    let url = "http://www.haskell.org/haskellwiki/Haskell"
        c   = Content TextHtml html
    resp <- diffbot token url $ setContent (Just c) mk
    assertBool "Nothing" $ isJust resp


emptyToken :: Request a => a -> Assertion
emptyToken req = do
    resp <- diffbot "" "" req
    assertBool "Nothing" $ isJust resp
    `E.catch` (\(StatusCodeException s _ _) ->
                   assertBool "Another exception" $ statusCode s == 401)


crawlApiUrl :: Assertion
crawlApiUrl = let c = defCrawl "sampleDiffbotCrawl"
                                  ["http://blog.diffbot.com"]
                  a = setFields (Just "querystring,meta") defArticle
              in crawlCommand' (Create c { crawlApi = Just $ toReq a }) (assertResp "Create")


crawlCommand :: Assertion
crawlCommand = do
    let name = "testCrawl"
        c = defCrawl name ["http://blog.diffbot.com"]
    crawlCommand' (Create c)    (assertResp "Create")
    crawlCommand' List          (assertJobs "List")
    crawlCommand' (Show name)   (assertJob "Show" name)
    crawlCommand' (Pause name)  (assertJobStatus "Pause" name (== 6))
    crawlCommand' (Resume name) (assertJobStatus "Resume" name (/= 6))
    crawlCommand' (Delete name) (assertNoJobs "Delete")
  where
    assertJobs c resp = do
      assertResp c resp
      let r = fromJust resp
      assertBool (c ++ ": no jobs.") $ isJust (responseJobs r)
      assertBool (c ++ ": empty jobs list.") ((/= 0) . length . fromJust $ responseJobs r)

    assertJob c name resp = do
      assertJobs c resp
      assertEqual (c ++ ": wrong job name.") name (jobName . head . fromJust . responseJobs $ fromJust resp)

    assertJobStatus c name test resp = do
      assertJobs c resp
      let job = find (\j -> jobName j == name) . fromJust $ responseJobs $ fromJust resp
      assertBool (c ++ ": no such job.") $ isJust job
      assertBool (c ++ ": wrong status code.") $ test . jobStatusCode . jobStatus $ fromJust job

    assertNoJobs c resp = do
      assertResp c resp
      assertBool (c ++ ": unexpected response") $ isNothing (responseJobs $ fromJust resp)


assertResp :: String -> Maybe a -> Assertion
assertResp c resp = do
    assertBool (c ++ ": no response.") $ isJust resp


crawlCommand' :: Command -> (Maybe Response -> Assertion) -> Assertion
crawlCommand' com assertion = do
    resp <- crawlbot token com
    assertion resp


html :: BL.ByteString
html = "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\" dir=\"ltr\">\n\t<head>\n\t\t<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n\t\t<meta name=\"generator\" content=\"MediaWiki 1.19.5-1\" />\n<link rel=\"shortcut icon\" href=\"/favicon.ico\" />\n<link rel=\"search\" type=\"application/opensearchdescription+xml\" href=\"/haskellwiki/opensearch_desc.php\" title=\"HaskellWiki (en)\" />\n<link rel=\"EditURI\" type=\"application/rsd+xml\" href=\"http://www.haskell.org/haskellwiki/api.php?action=rsd\" />\n<link rel=\"copyright\" href=\"/haskellwiki/HaskellWiki:Copyrights\" />\n<link rel=\"alternate\" type=\"application/atom+xml\" title=\"HaskellWiki Atom feed\" href=\"/haskellwiki/index.php?title=Special:RecentChanges&amp;feed=atom\" />\t\t<title>HaskellWiki</title>\n\t\t<style type=\"text/css\" media=\"screen, projection\">/*<![CDATA[*/\n\t\t\t@import \"/wikistatic/skins//common/shared.css?303\";\n\t\t\t@import \"/wikistatic/skins//hawiki/main.css?303\";\n\t\t/*]]>*/</style>\n\t\t<link rel=\"stylesheet\" type=\"text/css\" media=\"print\" href=\"/wikistatic/skins//common/commonPrint.css?303\" />\n\t\t<!--[if lt IE 5.5000]><style type=\"text/css\">@import \"/wikistatic/skins//hawiki/IE50Fixes.css?303\";</style><![endif]-->\n\t\t<!--[if IE 5.5000]><style type=\"text/css\">@import \"/wikistatic/skins//hawiki/IE55Fixes.css?303\";</style><![endif]-->\n\t\t<!--[if IE 6]><style type=\"text/css\">@import \"/wikistatic/skins//hawiki/IE60Fixes.css?303\";</style><![endif]-->\n\t\t<!--[if IE 7]><style type=\"text/css\">@import \"/wikistatic/skins//hawiki/IE70Fixes.css?303\";</style><![endif]-->\n\t\t<!--[if lte IE 7]><script type=\"text/javascript\" src=\"/wikistatic/skins//hawiki/IEFixes.js?303\"></script>\n\t\t<meta http-equiv=\"imagetoolbar\" content=\"no\" /><![endif]-->\n                                                <script type=\"text/javascript\">\n                        var isMSIE55 = (window.showModalDialog && window.clipboardData && window.createPopup); /*alert(\"test: \" + isMSIE55);*/</script>\n\n\t\t<script>if(window.mw){\nmw.config.set({\"wgCanonicalNamespace\":\"\",\"wgCanonicalSpecialPageName\":false,\"wgNamespaceNumber\":0,\"wgPageName\":\"Haskell\",\"wgTitle\":\"Haskell\",\"wgCurRevisionId\":56799,\"wgArticleId\":1,\"wgIsArticle\":true,\"wgAction\":\"view\",\"wgUserName\":null,\"wgUserGroups\":[\"*\"],\"wgCategories\":[],\"wgBreakFrames\":false,\"wgPageContentLanguage\":\"en\",\"wgSeparatorTransformTable\":[\"\",\"\"],\"wgDigitTransformTable\":[\"\",\"\"],\"wgRelevantPageName\":\"Haskell\",\"wgRestrictionEdit\":[\"sysop\"],\"wgRestrictionMove\":[\"sysop\"],\"wgIsMainPage\":true});\n}</script>\n\t\t<script type=\"text/javascript\" src=\"/wikistatic/skins//common/wikibits.js?303\"><!-- wikibits js --></script>\n\t\t<!-- Head Scripts -->\n<script src=\"http://www.haskell.org/haskellwiki/load.php?debug=false&amp;lang=en&amp;modules=startup&amp;only=scripts&amp;skin=hawiki&amp;*\"></script>\n<script>if(window.mw){\nmw.config.set({\"wgCanonicalNamespace\":\"\",\"wgCanonicalSpecialPageName\":false,\"wgNamespaceNumber\":0,\"wgPageName\":\"Haskell\",\"wgTitle\":\"Haskell\",\"wgCurRevisionId\":56799,\"wgArticleId\":1,\"wgIsArticle\":true,\"wgAction\":\"view\",\"wgUserName\":null,\"wgUserGroups\":[\"*\"],\"wgCategories\":[],\"wgBreakFrames\":false,\"wgPageContentLanguage\":\"en\",\"wgSeparatorTransformTable\":[\"\",\"\"],\"wgDigitTransformTable\":[\"\",\"\"],\"wgRelevantPageName\":\"Haskell\",\"wgRestrictionEdit\":[\"sysop\"],\"wgRestrictionMove\":[\"sysop\"],\"wgIsMainPage\":true});\n}</script><script>if(window.mw){\nmw.loader.implement(\"user.options\",function($){mw.user.options.set({\"ccmeonemails\":0,\"cols\":80,\"date\":\"default\",\"diffonly\":0,\"disablemail\":0,\"disablesuggest\":0,\"editfont\":\"default\",\"editondblclick\":0,\"editsection\":1,\"editsectiononrightclick\":0,\"enotifminoredits\":0,\"enotifrevealaddr\":0,\"enotifusertalkpages\":1,\"enotifwatchlistpages\":0,\"extendwatchlist\":0,\"externaldiff\":0,\"externaleditor\":0,\"fancysig\":0,\"forceeditsummary\":0,\"gender\":\"unknown\",\"hideminor\":0,\"hidepatrolled\":0,\"highlightbroken\":1,\"imagesize\":2,\"justify\":0,\"math\":1,\"minordefault\":0,\"newpageshidepatrolled\":0,\"nocache\":0,\"noconvertlink\":0,\"norollbackdiff\":0,\"numberheadings\":1,\"previewonfirst\":0,\"previewontop\":1,\"quickbar\":5,\"rcdays\":7,\"rclimit\":50,\"rememberpassword\":0,\"rows\":25,\"searchlimit\":20,\"showhiddencats\":0,\"showjumplinks\":1,\"shownumberswatching\":1,\"showtoc\":1,\"showtoolbar\":1,\"skin\":\"hawiki\",\"stubthreshold\":0,\"thumbsize\":2,\"underline\":2,\"uselivepreview\":0,\"usenewrc\":0,\"watchcreations\":0,\"watchdefault\":0,\"watchdeletion\":0,\n\"watchlistdays\":3,\"watchlisthideanons\":0,\"watchlisthidebots\":0,\"watchlisthideliu\":0,\"watchlisthideminor\":0,\"watchlisthideown\":0,\"watchlisthidepatrolled\":0,\"watchmoves\":0,\"wllimit\":250,\"variant\":\"en\",\"language\":\"en\",\"searchNs0\":true,\"searchNs1\":false,\"searchNs2\":false,\"searchNs3\":false,\"searchNs4\":false,\"searchNs5\":false,\"searchNs6\":false,\"searchNs7\":false,\"searchNs8\":false,\"searchNs9\":false,\"searchNs10\":false,\"searchNs11\":false,\"searchNs12\":false,\"searchNs13\":false,\"searchNs14\":false,\"searchNs15\":false});;},{},{});mw.loader.implement(\"user.tokens\",function($){mw.user.tokens.set({\"editToken\":\"+\\\\\",\"watchToken\":false});;},{},{});\n\n/* cache key: wikidb:resourceloader:filter:minify-js:7:befcdb5e3b24ff89f900613de9ed4ea3 */\n}</script>\n<script>if(window.mw){\nmw.loader.load([\"mediawiki.page.startup\",\"mediawiki.legacy.wikibits\",\"mediawiki.legacy.ajax\"]);\n}</script>\t</head>\n<body class=\"mediawiki ltr ns-0 ns-subject page-Haskell skin-hawiki\">\n   <div id=\"topbar\" class=\"noprint\">\n\t<div class=\"portlet noprint\" id=\"p-personal\">\n\t\t<h5>Personal tools</h5>\n\t\t<div class=\"pBody\">\n\t\t\t<ul><li><a class=\"homebutton\" href=\"/haskellwiki/Haskell\">Home</a></li>\n\t\t\t\t<li id=\"pt-login\"><a href=\"/haskellwiki/index.php?title=Special:UserLogin&amp;returnto=Haskell\">Log in</a></li>\n\t\t\t</ul>\n\t\t</div>\n\t</div>\n        \t  <div id=\"p-search\">\n\t    <div id=\"searchBody\" class=\"pBody\">\n\t       <form action=\"/haskellwiki/index.php\" id=\"searchform\"><div>\n\t          <input type='hidden' name=\"title\" value=\"Special:Search\"/>\n\t          <input id=\"searchInput\" name=\"search\" type=\"text\" value=\"\" />\n\t\t\t\t<input type='submit' name=\"go\" class=\"searchButton\" id=\"searchGoButton\"\tvalue=\"Go\" />&nbsp;\n\t\t\t\t<input type='submit' name=\"fulltext\" class=\"searchButton\" id=\"mw-searchButton\" value=\"Search\" />\n\n\t         </div></form>\n\t    </div>\n\t  </div>\n   </div>\n\t<div id=\"globalWrapper\" class=\"homepage\" >\n\t<div class=\"portlet\" id=\"p-logo\">\n\t\t<a style=\"background-image: url(/wikistatic/haskellwiki_logo.png);\" href=\"/haskellwiki/Haskell\"></a>\n\t</div>\n\t<div id=\"column-content\">\n        <div id=\"notice-area\" class=\"noprint\">\n        <!-- ?php $this->data['sitenotice'] = 'This is a test instance.  Do not edit, your changes will be lost.'; ? -->\n\t\t\t        </div>\n        <div id=\"content-wrapper\">\n\t<div id=\"p-cactions\" class=\"portlet noprint\">\n\t\t<h5>Views</h5>\n\t\t<div class=\"pBody\">\n\t\t\t<ul>\n\t\n\t\t\t\t <li id=\"ca-nstab-main\" class=\"selected\"><a href=\"/haskellwiki/Haskell\">Page</a></li>\n\t\t\t\t <li id=\"ca-talk\"><a href=\"/haskellwiki/Talk:Haskell\">Discussion</a></li>\n\t\t\t\t <li id=\"ca-viewsource\"><a href=\"/haskellwiki/index.php?title=Haskell&amp;action=edit\">View source</a></li>\n\t\t\t\t <li id=\"ca-history\"><a href=\"/haskellwiki/index.php?title=Haskell&amp;action=history\">History</a></li>\t\t\t</ul>\n\t\t</div>\n\t</div>\n                        <div id=\"content\">\n\t\t<a name=\"top\" id=\"top\"></a>\n                        <h1 id=\"firstHeading\" class=\"firstHeading\">Haskell</h1>\n\t\t<div id=\"bodyContent\">\n\t\t\t<h3 id=\"siteSub\">From HaskellWiki</h3>\n\t\t\t<div id=\"contentSub\"></div>\n\t\t\t<div id=\"jump-to-nav\">Jump to: <a href=\"#column-one\">navigation</a>, <a href=\"#searchInput\">search</a></div>\t\t\t<!-- start content -->\n\t\t\t<div id=\"mw-content-text\" lang=\"en\" dir=\"ltr\" class=\"mw-content-ltr\"><p><br />\n</p>\n<div class=\"bg-image\">\n<div class=\"title\">The Haskell Programming Language</div>\n<div class=\"intro\">\n<p>Haskell is an advanced <a href=\"/haskellwiki/Functional_programming\" title=\"Functional programming\">purely-functional</a>\nprogramming language. An open-source product of more than twenty years of cutting-edge research, \nit allows rapid development of robust, concise, correct\nsoftware. With strong support for <a href=\"/haskellwiki/Foreign_Function_Interface\" title=\"Foreign Function Interface\">integration with other languages</a>,\nbuilt-in <a href=\"/haskellwiki/Parallel\" title=\"Parallel\">concurrency and parallelism</a>, debuggers, profilers, <a rel=\"nofollow\" class=\"external text\" href=\"http://hackage.haskell.org/packages/hackage.html\">rich libraries</a> and an active community, Haskell makes it easier to produce flexible, maintainable, \nhigh-quality software.\n</p>\n</div>\n</div>\n<div class=\"wrap\">\n<div class=\"cols3 w1000\" style=\"margin: 0 auto; text-align: left\">\n<div class=\"c1\"><div class=\"pad\">\n<div class=\"subtitle\">Learn Haskell</div>\n<ul><li> <a href=\"/haskellwiki/Introduction\" title=\"Introduction\">What is Haskell?</a>\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://tryhaskell.org/\">Try Haskell in your browser</a>\n</li><li> <a href=\"/haskellwiki/Learning_Haskell\" title=\"Learning Haskell\">Learning resources</a>\n</li><li> <a href=\"/haskellwiki/Books\" title=\"Books\">Books</a> &amp; <a href=\"/haskellwiki/Tutorials\" title=\"Tutorials\">tutorials</a>\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://haskell.org/ghc/docs/7.6-latest/html/libraries/index.html\">Library documentation</a>\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"https://haskell.fpcomplete.com/school/\">School of Haskell</a>, hosted by FP Complete\n</li></ul>\n</div></div>\n<div class=\"c2\"><div class=\"pad\">\n<div class=\"subtitle\">Use Haskell</div>\n<ul><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://hackage.haskell.org/platform/\"><span class=\"button orange\">Download Haskell</span></a>\n</li><li> <a href=\"/haskellwiki/Language_and_library_specification\" title=\"Language and library specification\">Language specification</a>\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://hackage.haskell.org/packages/hackage.html\">Hackage library database</a>\n</li><li> <a href=\"/haskellwiki/Applications_and_libraries\" title=\"Applications and libraries\">Applications and libraries</a>\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://haskell.org/hoogle/\">Hoogle</a> and <a rel=\"nofollow\" class=\"external text\" href=\"http://holumbus.fh-wedel.de/hayoo/\">Hayoo</a> API search\n</li><li> <a href=\"/haskellwiki/IDEs\" title=\"IDEs\">IDEs</a>, <a href=\"/haskellwiki/Editors\" title=\"Editors\">Editors</a>, and <a href=\"/haskellwiki/Development_Libraries_and_Tools\" title=\"Development Libraries and Tools\"> Tools</a>\n</li></ul>\n</div></div>\n<div class=\"c3\"><div class=\"pad\">\n<div class=\"subtitle\">Join the Community</div>\n<ul><li> Haskell on <a rel=\"nofollow\" class=\"external text\" href=\"http://www.reddit.com/r/haskell/\">Reddit</a>, <a rel=\"nofollow\" class=\"external text\" href=\"http://stackoverflow.com/questions/tagged?tagnames=haskell\">Stack Overflow</a>, <a rel=\"nofollow\" class=\"external text\" href=\"https://plus.google.com/communities/104818126031270146189\">G+</a>\n</li><li> <a href=\"/haskellwiki/Mailing_lists\" title=\"Mailing lists\">Mailing lists</a>, <a href=\"/haskellwiki/IRC_channel\" title=\"IRC channel\">IRC channels</a>\n</li><li> <a href=\"/haskellwiki/Category:Haskell\" title=\"Category:Haskell\">Wiki</a> (<a href=\"/haskellwiki/HaskellWiki:Contributing\" title=\"HaskellWiki:Contributing\">how to contribute</a>)\n</li><li> <a href=\"/haskellwiki/Haskell_Communities_and_Activities_Report\" title=\"Haskell Communities and Activities Report\">Communities and Activities Reports</a>\n</li><li> Haskell in <a href=\"/haskellwiki/Haskell_in_industry\" title=\"Haskell in industry\">industry</a>, <a href=\"/haskellwiki/Haskell_in_research\" title=\"Haskell in research\">research</a> and <a href=\"/haskellwiki/Haskell_in_education\" title=\"Haskell in education\">education</a>.\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://planet.haskell.org/\">Planet Haskell</a> <a rel=\"nofollow\" class=\"external text\" href=\"http://planet.haskell.org/rss20.xml\"><img src=\"http://haskell.org/wikiupload/7/7c/Rss16.png\" alt=\"Rss16.png\" /></a>, <a rel=\"nofollow\" class=\"external text\" href=\"http://themonadreader.wordpress.com/\">The Monad.Reader</a>\n</li><li> Local <a href=\"/haskellwiki/User_groups\" title=\"User groups\">user groups</a>\n</li></ul>\n</div></div>\n</div>\n</div>\n<div class=\"visualClear\"></div>\n<div class=\"home-dynamic\">\n<div class=\"wrap\">\n<div style=\"text-align: center; text-shadow: white 0 1px; color: #666; font-size:smaller; margin-top:5px\">News</div>\n<div class=\"cols3 w1000\">\n<div class=\"c1\"><div class=\"pad\">\n<div class=\"subtitle\">Headlines</div>\n<ul><li> <i>2013:</i>\n<ul><li> <b><a rel=\"nofollow\" class=\"external text\" href=\"http://hackage.haskell.org/\">Hackage 2</a></b> is now live, powered by Haskell.\n</li><li> <b><a rel=\"nofollow\" class=\"external text\" href=\"https://www.fpcomplete.com/business/haskell-center/overview/\">FP Haskell Center</a></b>, the commercial in-browser IDE by FP Complete <b><a rel=\"nofollow\" class=\"external text\" href=\"https://www.fpcomplete.com/business/blog/fp-complete-launches-fp-haskell-center-the-worlds-1st-haskell-ide-and-deployment-platform/\">has been released</a></b>.\n</li><li> <b><a rel=\"nofollow\" class=\"external text\" href=\"http://www.haskell.org/pipermail/haskell/2013-September/039154.html\">Cabal 1.18</a></b> has been released.\n</li><li> The <b><a rel=\"nofollow\" class=\"external text\" href=\"http://haskell.org/platform?2013.2\">Haskell Platform 2013.2</a></b> is now available\n</li><li> <b><a rel=\"nofollow\" class=\"external text\" href=\"http://www.fpcomplete.com\">FP Complete</a></b> has compiled a short <b><a rel=\"nofollow\" class=\"external text\" href=\"https://docs.google.com/forms/d/1dZVuT_2-x2C515YeXnAzXwddIvftALwgSoz2NYjS4aE/viewform\">survey</a></b> to help build the Haskell user community.\n</li></ul>\n</li></ul>\n<ul><li> <i>2012:</i>\n<ul><li> The <b><a rel=\"nofollow\" class=\"external text\" href=\"http://haskell.org/platform\">Haskell Platform 2012.4</a></b> is now available\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://www.haskell.org/ghc/\">GHC 7.6</a> is released\n</li><li> The <b><a rel=\"nofollow\" class=\"external text\" href=\"http://haskell.org/platform\">Haskell Platform 2012.2</a></b> is now available\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://www.yesodweb.com/blog/2012/04/announcing-yesod-1-0\">Yesod 1.0</a> is now available\n</li><li> <a rel=\"nofollow\" class=\"external text\" href=\"http://www.haskell.org/ghc/\">GHC 7.4</a> is released\n</li><li> O'Reilly have announced a forthcoming book on <a rel=\"nofollow\" class=\"external text\" href=\"http://www.haskell.org/pipermail/haskell/2012-May/023328.html\">Parallel and Concurrent Haskell</a>\n</li></ul>\n</li></ul>\n</div></div>\n<div class=\"c2\"><div class=\"pad\">\n<div class=\"subtitle\">Upcoming Events</div>\n<dl><dt><a rel=\"nofollow\" class=\"external text\" href=\"http://staff.science.uva.nl/~grelck/nl-fp-day-2014.html\">NL-FP day 2014</a> \n</dt><dd>January 10, 2014, Amsterdam, NLD\n</dd></dl>\n<dl><dt> Well-Typed's introductory and advanced <a rel=\"nofollow\" class=\"external text\" href=\"http://www.well-typed.com/services_training\">Haskell courses</a>\n</dt><dd>February 10-11 (Introductory) and February 12-13 (Advanced), 2014, London, UK\n</dd></dl>\n<dl><dt><a rel=\"nofollow\" class=\"external text\" href=\"http://skillsmatter.com/event/scala/functional-programming-exchange-1819\">Functional Programming eXchange 2014</a> \n</dt><dd>March 14, 2014, London, UK\n</dd></dl>\n<div class=\"subtitle\">Recent Events</div>\n<dl><dt><a rel=\"nofollow\" class=\"external text\" href=\"http://fpdays.net/fpdays2013/\">FP Days</a> \n</dt><dd>October 24-25, 2013, Cambdrige, UK\n</dd></dl>\n<dl><dt><a rel=\"nofollow\" class=\"external text\" href=\"http://www.well-typed.com/services_training\">Introductory</a> and <a rel=\"nofollow\" class=\"external text\" href=\"http://www.well-typed.com/services_training\">Advanced</a> Haskell courses (UK)\n</dt><dd>October 7-8 (Introductory) and October 10-11 (Advanced), 2013, London, UK\n</dd></dl>\n<dl><dt><a rel=\"nofollow\" class=\"external text\" href=\"http://skillsmatter.com/event/scala/haskell-exchange\">Haskell eXchange</a> \n</dt><dd>October 9, 2013, London, UK\n</dd></dl>\n<dl><dt><a rel=\"nofollow\" class=\"external text\" href=\"http://www.haskell.org/haskell-symposium/2013/\">Haskell Symposium</a> conference\n</dt><dd>September 23-24, 2013, Boston, USA\n</dd></dl>\n<dl><dt><a rel=\"nofollow\" class=\"external text\" href=\"http://cufp.org\">Commercial Users of Functional Programming</a> conference\n</dt><dd>September 22-24, 2013, Boston, USA\n</dd></dl>\n</div></div>\n<div class=\"c3\"><div class=\"pad\">\n<div class=\"subtitle\">Recent Package Updates <a rel=\"nofollow\" class=\"external text\" href=\"http://haskell.org/haskellwiki/Hackage_statistics\"><img src=\"http://i.imgur.com/mHvNV.png\" alt=\"mHvNV.png\" /></a> <a rel=\"nofollow\" class=\"external text\" href=\"http://hackage.haskell.org/packages/archive/recent.rss\"><img src=\"http://haskell.org/wikiupload/7/7c/Rss16.png\" alt=\"Rss16.png\" /></a></div>\n<div style=\"font-size:80%\">\n<p>See <a rel=\"nofollow\" class=\"external text\" href=\"http://hackage.haskell.org/recent\">here</a>\n</p>\n</div>\n</div></div>\n<div class=\"visualClear\"></div>\n</div>\n<div class=\"visualClear\"></div>\n</div>\n</div>\n<div style=\"text-align:center; clear: both; background: #eee; padding: 1px; margin: 0; font-size: 80%;\"><a href=\"/haskellwiki/Donate_to_Haskell.org\" title=\"Donate to Haskell.org\">Donate to Haskell.org</a></div>\n\n<!-- \nNewPP limit report\nPreprocessor node count: 49/1000000\nPost\226\128\144expand include size: 5040/2097152 bytes\nTemplate argument size: 0/2097152 bytes\nExpensive parser function count: 0/100\n-->\n\n<!-- Saved in parser cache with key wikidb:pcache:idhash:1-0!*!0!*!*!*!* and timestamp 20140108101404 -->\n</div><div class=\"printfooter\">\nRetrieved from \"<a href=\"http://www.haskell.org/haskellwiki/index.php?title=Haskell&amp;oldid=56799\">http://www.haskell.org/haskellwiki/index.php?title=Haskell&amp;oldid=56799</a>\"</div>\n\t\t\t<div id='catlinks' class='catlinks catlinks-allhidden'></div>\t\t\t<!-- end content -->\n\t\t\t\t\t\t<div class=\"visualClear\"></div>\n\t\t</div>\n\t</div>\n\t\t</div></div>\n\t\t<div id=\"column-one\">\n\t<script type=\"text/javascript\"> if (window.isMSIE55) fixalpha(); </script>\n\t<div class='generated-sidebar portlet' id='p-navigation'>\n\t\t<h5>Navigation</h5>\n\t\t<div class='pBody'>\n\t\t\t<ul>\n\t\t\t\t<li id=\"n-mainpage\"><a href=\"/haskellwiki/Haskell\">Haskell</a></li>\n\t\t\t\t<li id=\"n-portal\"><a href=\"/haskellwiki/HaskellWiki:Community\">Wiki community</a></li>\n\t\t\t\t<li id=\"n-recentchanges\"><a href=\"/haskellwiki/Special:RecentChanges\">Recent changes</a></li>\n\t\t\t\t<li id=\"n-randompage\"><a href=\"/haskellwiki/Special:Random\">Random page</a></li>\n\t\t\t</ul>\n\t\t</div>\n\t</div>\n\t<div class=\"portlet\" id=\"p-tb\">\n\t\t<h5>Toolbox</h5>\n\t\t<div class=\"pBody\">\n\t\t\t<ul>\n\t\t\t\t<li id=\"t-whatlinkshere\"><a href=\"/haskellwiki/Special:WhatLinksHere/Haskell\">What links here</a></li>\n\t\t\t\t<li id=\"t-recentchangeslinked\"><a href=\"/haskellwiki/Special:RecentChangesLinked/Haskell\">Related changes</a></li>\n<li id=\"t-specialpages\"><a href=\"/haskellwiki/Special:SpecialPages\">Special pages</a></li>\n\t\t\t\t<li id=\"t-print\"><a href=\"/haskellwiki/index.php?title=Haskell&amp;printable=yes\" rel=\"alternate\">Printable version</a></li>\t\t\t\t<li id=\"t-permalink\"><a href=\"/haskellwiki/index.php?title=Haskell&amp;oldid=56799\">Permanent link</a></li>\t\t\t</ul>\n\t\t</div>\n\t</div>\n\t\t</div><!-- end of the left (by default at least) column -->\n\t\t\t<div class=\"visualClear\"></div>\n\t\t\t<div id=\"footer\">\n\t\t\t\t<div id=\"f-poweredbyico\"><a href=\"//www.mediawiki.org/\"><img src=\"/wikistatic/skins//common/images/poweredby_mediawiki_88x31.png\" height=\"31\" width=\"88\" alt=\"Powered by MediaWiki\" /></a></div>\n\t\t\t<ul id=\"f-list\">\n\t\t\t\t\t<li id=\"lastmod\"> This page was last modified on 9 September 2013, at 22:38.</li>\n\t\t\t\t\t<li id=\"viewcount\">This page has been accessed 7,274,682 times.</li>\n\t\t\t\t\t<li id=\"copyright\">Recent content is available under <a href=\"/haskellwiki/HaskellWiki:Copyrights\" title=\"HaskellWiki:Copyrights\">a simple permissive license</a>.</li>\n\t\t\t\t\t<li id=\"privacy\"><a href=\"/haskellwiki/HaskellWiki:Privacy_policy\" title=\"HaskellWiki:Privacy policy\">Privacy policy</a></li>\n\t\t\t\t\t<li id=\"about\"><a href=\"/haskellwiki/HaskellWiki:About\" title=\"HaskellWiki:About\">About HaskellWiki</a></li>\n\t\t\t\t\t<li id=\"disclaimer\"><a href=\"/haskellwiki/HaskellWiki:General_disclaimer\" title=\"HaskellWiki:General disclaimer\">Disclaimers</a></li>\n\t\t\t</ul>\n\t\t</div>\n</div>\n<script>if(window.mw){\nmw.loader.load([\"mediawiki.user\",\"mediawiki.page.ready\"], null, true);\n}</script>\n<script src=\"http://www.haskell.org/haskellwiki/load.php?debug=false&amp;lang=en&amp;modules=site&amp;only=scripts&amp;skin=hawiki&amp;*\"></script>\n<!-- Served in 0.102 secs. --><script type=\"text/javascript\">\n\n  var _gaq = _gaq || [];\n  _gaq.push(['_setAccount', 'UA-15375175-1']);\n  _gaq.push(['_trackPageview']);\n\n  (function() {\n    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;\n    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';\n    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);\n  })();\n\n</script>\n</body></html>\n"
