


/*
  Procedure looks for any Corporate Flex member who was added within the last day 
  and sends a welcome email.  These members are omitted from the normal new 
  Member email.
*/

CREATE PROCEDURE [dbo].[mmsEmailNewCorporateFlexMembers]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @MemberID INT
DECLARE @FirstName VARCHAR(50)
DECLARE @URL VARCHAR(200)
DECLARE @EmailAddress VARCHAR(140)
DECLARE @SubjectLine VARCHAR(150)
DECLARE @MemberToken BINARY(20)
DECLARE @ReimbursementProgramName VARCHAR(50)
DECLARE @EmailText VARCHAR(MAX)
DECLARE @EnrollmentType VARCHAR(25)
DECLARE @LastProcessed DATETIME
DECLARE @CurrentHour DATETIME
CREATE TABLE #NewMembers (
				MemberID INT, 
				FirstName VARCHAR(50), 
				EmailAddress VARCHAR(140),
				MemberToken BINARY(20),
				ReimbursementProgramName VARCHAR(50),
				EnrollmentType VARCHAR(25))

--Get the time of the last Run
SET @CurrentHour = DATEADD(HH,DATEPART(HH,GETDATE()),CONVERT(VARCHAR(11),GETDATE()))
SELECT @LastProcessed = LastProcessedDateTime
FROM vLastProcessedDateTime
WHERE Description = 'New Member Corporate Flex Email'



/* Find all Members who will get emailed */

--Find all new Corporate Flex Membership created yesterday
INSERT INTO #NewMembers
SELECT m.MemberID, m.FirstName, m.EmailAddress, m.MemberToken, 
	   rp.ReimbursementProgramName, 'NewMember'
FROM vMember m
JOIN vMembership ms
  ON ms.MembershipID = m.MembershipID
JOIN vMembershipType mt
  ON mt.MembershipTypeID = ms.MembershipTypeID
JOIN vProduct p
  ON p.ProductID = mt.ProductID
JOIN vMemberReimbursement mr
  ON m.MemberID = mr.MemberID
JOIN vReimbursementProgram rp
  ON rp.ReimbursementProgramID = mr.ReimbursementProgramID
WHERE p.Description LIKE '%Corporate Flex%'
  AND ISNULL(ms.InsertedDateTime,'1999-01-01') >= @LastProcessed
  AND ISNULL(ms.InsertedDateTime,'1999-01-01') < @CurrentHour
  AND m.MemberToken IS NOT NULL
  AND m.EmailAddress IS NOT NULL
  AND m.EmailAddress LIKE '%@%.%'

--Find Existing members who were enrolled into a Corporate Flex program with myLT Account
--Since the Enrollment Date is midnight of the day the member was enrolled, we are checking for
--the day prior to the LastProcessed Time
INSERT INTO #NewMembers
SELECT m.MemberID, m.FirstName, m.EmailAddress, m.MemberToken,
	   rp.ReimbursementProgramName, 'ExistingMemberWithMylt'
FROM vMember m
JOIN vMembership ms
  ON ms.MembershipID = m.MembershipID
JOIN vMemberReimbursement mr
  ON m.MemberID = mr.MemberID
JOIN vReimbursementProgram rp
  ON rp.ReimbursementProgramID = mr.ReimbursementProgramID
JOIN vReimbursementProgramIdentifierFormat rpif
  ON rpif.ReimbursementProgramID = rp.ReimbursementProgramID
JOIN tmpLTFUserIdentity ui
  ON ui.Member_ID = m.MemberID
LEFT JOIN #NewMembers NM 
  ON M.MemberID = NM.MemberID
WHERE rpif.Description LIKE '%Corporate Flex%'
  AND mr.EnrollmentDate >= DATEADD(DD,-1,@LastProcessed)
  AND mr.EnrollmentDate < DATEADD(DD,-1,@CurrentHour)
 -- AND ISNULL(ms.InsertedDateTime,'1999-01-01') < @LastProcessed
--  AND m.MemberToken IS NOT NULL
  AND m.EmailAddress IS NOT NULL
  AND m.EmailAddress LIKE '%@%.%'
  AND NM.MemberID IS NULL
--Find Existing members who were enrolled into a Corporate Flex program with no myLT Account
--Since the Enrollment Date is midnight of the day the member was enrolled, we are checking for
--the day prior to the LastProcessed TimeINSERT INTO #NewMembers
INSERT INTO #NewMembers
SELECT m.MemberID, m.FirstName, m.EmailAddress, m.MemberToken,  
	   rp.ReimbursementProgramName, 'ExistingMemberNoMylt'
FROM vMember m
JOIN vMembership ms
  ON ms.MembershipID = m.MembershipID
JOIN vMemberReimbursement mr
  ON m.MemberID = mr.MemberID
JOIN vReimbursementProgram rp
  ON rp.ReimbursementProgramID = mr.ReimbursementProgramID
JOIN vReimbursementProgramIdentifierFormat rpif
  ON rpif.ReimbursementProgramID = rp.ReimbursementProgramID
LEFT JOIN tmpLTFUserIdentity ui
  ON ui.Member_ID = m.MemberID
LEFT JOIN #NewMembers NM 
  ON M.MemberID = NM.MemberID
WHERE rpif.Description LIKE '%Corporate Flex%'
  AND mr.EnrollmentDate >= DATEADD(DD,-1,@LastProcessed)
  AND mr.EnrollmentDate < DATEADD(DD,-1,@CurrentHour)
 -- AND ISNULL(ms.InsertedDateTime,'1999-01-01') < @LastProcessed
  AND ui.Member_ID IS NULL --No myLT Account
  AND m.MemberToken IS NOT NULL
  AND m.EmailAddress IS NOT NULL
  AND m.EmailAddress LIKE '%@%.%'
  AND NM.MemberID IS NULL

--Create Cursor to loop through each Member
DECLARE MemberCursor
CURSOR FOR
   SELECT MemberID, 
		  FirstName, 
		  EmailAddress,
		  MemberToken,
		  ReimbursementProgramName,
		  EnrollmentType
   FROM #NewMembers

OPEN MemberCursor

FETCH NEXT
FROM  MemberCursor
INTO  @MemberID, 
	  @FirstName, 
	  @EmailAddress,
	  @MemberToken,
	  @ReimbursementProgramName,
	  @EnrollmentType


WHILE @@FETCH_STATUS = 0

BEGIN

/* Create the Email */
--Email text varies by how the member was enrolled
SELECT @SubjectLine = @ReimbursementProgramName + ' Wellness Program in partnership with Life Time Fitness',
	   @URL = 'https://mylt.lifetimefitness.com/index.cfm?event=general.autoRegister&strMemberkey=' + master.dbo.fn_varbintohexstr (@MemberToken),
	   @EmailText =
--Newly Created Members
CASE WHEN @EnrollmentType = 'NewMember'
     THEN  '
<p><span style="font-size: 12pt">
	Dear ' + @FirstName + ',
	</span>
	</p>

<p><b><span style="font-size: 12pt">
	Announcing your new wellness benefit brought to you by ' + @ReimbursementProgramName + ', in partnership with Life Time Fitness.
	</span></b>
	</p>

<p><span style="font-size: 11pt">
	You now have access to one of the most comprehensive health management programs around. 
	It&#39;s free to you, as part of your ' + @ReimbursementProgramName + ' employee benefits. 
	The program includes personalized health and fitness programs, tools and reliable information prepared by the experts at Life Time Fitness and Mayo Clinic.
	</span>
	</p>

<p><span style="font-size: 12pt">
	Take a minute to review all the offerings included in your new wellness benefit:
	</span>
	</p>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">myLT.com Online Personal Account</span></b><br>
	Connect to all the components of your wellness benefit in one convenient place. 
	It&#39;s continually updated with relevant health information based on your interests.
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b><a href = "' + @URL + '">Click here</a> or paste ' + @URL + ' in your browser window to activate your account.</b></li>
	<li><b>You&#39;ll create a unique username and password to build your account.</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">RiskPoint Health Screening</span></b><br>
	A simple blood test gives you a look at more than 40 important health points such as cholesterol, glucose, triglycerides, protein and complete blood count. 
	A detailed personal report will explain your results and provide you with educational materials.  
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b>To schedule, go to myLT.com > my wellness benefit  > RiskPoint Health Screening</b></li>
	<li><b>Use the Username and Password you created on myLT.com</b></li>
	<li><b>To receive your free results, complete the screening within 60 days</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">Mayo Clinic Tools & Trackers</span></b><br>
	A personalized and interactive health management resource that combines smart technology, Mayo Clinic expertise and personalized resources, tools and trackers. 
	Complete a survey to create a Personal Action Plan, which will guide you to informational and motivational resources based on your specific needs and interests.
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b>Log into myLT.com and go to my wellness benefit > Mayo Clinic Tools & Trackers</b></li>
	<li><b>Enter your Life Time Fitness Member # in the Unique ID field(In myLT.com, click on your picture or name to get your #)</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;"><i>Experience Life</i> Magazine</span></b><br>
	You&#39;ll automatically receive a subscription to <i>Experience Life</i>. 
	Published 10 times per year, it&#39;s our highly regarded healthy way of life magazine.
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">Member Advantage</span></b><br>
	You now have access to Life Time&#39;s easy-to-use member discount program, which offers you exclusive savings at hundreds of partners nationally and locally.
	Receive discounts on products and services you use every day from national brands to local favorites. 
	<b>Go to myLT.com to view all the Member Advantage partners</b>
	</span>
	</p>

<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">Life Time Fitness Membership Savings</span></b><br>
	If you are not currently a member, join now for $0 joiner&#39;s fee and get monthly savings on your dues each month.* 
	To qualify you must join on your myLT.com page: 
	<b>Log into myLT.com and go to my wellness benefit > Join Life Time Fitness.</b>
	<b>If you are currently a Life Time Fitness member, call us at 1-952-229-7128 because you are eligible for savings on your monthly dues as part of this program.</b>
	</span>
	</p>
	
<p><span style="font-size: 11pt;">
	Our goal is to empower you with the tools you need to maintain good health.  
	We look forward to assisting you in your healthy way of life journey.  
	Contact us at totalhealth@lifetimefitness.com if you have questions regarding this wellness benefit.
	</span>
	</p>

<p><span style="font-size: 11pt;">
	Sincerely,<br>
	' + @ReimbursementProgramName + ' and Life Time Fitness
	</span>
	</p>

<br>

<p><span style="font-size: 10pt;">
	*If you enroll for a membership at Life Time Fitness and at a later date become ineligible for your company&#39;s wellness benefit, at that time you will be charged the standard monthly dues, including a subscription to <i>Experience Life.</i> 
	Membership dues, prices and fees are subject to change at any time. 
	Service or downgrade fees may apply to membership changes. 
	Cannot be combined with any other discounts. 
	</span>
	</p>
'
--Existing Member with myLT Accounts
     WHEN @EnrollmentType = 'ExistingMemberWithMylt'
     THEN '
<p><span style="font-size: 12pt">
	Dear ' + @FirstName + ',
	</span>
	</p>

<p><b><span style="font-size: 12pt">
	Announcing your new wellness benefit brought to you by ' + @ReimbursementProgramName + ', in partnership with Life Time Fitness.
	</span></b>
	</p>

<p><span style="font-size: 11pt">
	As a Life Time Fitness member, you&#39;ll receive a <b>credit on your monthly dues*</b> as part of your company&#39;s wellness program. 
	In addition the program includes personalized health and fitness programs, tools and reliable information prepared by the experts at Life Time Fitness and Mayo Clinic. 
	</span>
	</p>

<p><span style="font-size: 12pt">
	Take a minute to review all the offerings included in your new wellness benefit:
	</span>
	</p>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">myLT.com Online Personal Account</span></b><br>
	Connect to all the components of your wellness benefit in one convenient place. 
	It&#39;s continually updated with relevant health information based on your interests.
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b><a href="http://www.myLT.com">Click here</a> or paste www.myLT.com in your browser window to access your personal myLT.com account.</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">RiskPoint Health Screening</span></b><br>
	A simple blood test gives you a look at more than 40 important health points such as cholesterol, glucose, triglycerides, protein and complete blood count. 
	A detailed personal report will explain your results and provide you with educational materials.  
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b>To schedule, go to myLT.com > my wellness benefit  > RiskPoint Health Screening</b></li>
	<li><b>Use the Username and Password you created on myLT.com</b></li>
	<li><b>To receive your free results, complete the screening within 60 days</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">Mayo Clinic Tools & Trackers</span></b><br>
	A personalized and interactive health management resource that combines smart technology, Mayo Clinic expertise and personalized resources, tools and trackers. 
	Complete a survey to create a Personal Action Plan, which will guide you to informational and motivational resources based on your specific needs and interests.
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b>Log into myLT.com and go to my wellness benefit > Mayo Clinic Tools & Trackers</b></li>
	<li><b>Enter your Life Time Fitness Member # in the Unique ID field(In myLT.com, click on your picture or name to get your #)</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;"><i>Experience Life</i> Magazine</span></b><br>
	You&#39;ll automatically receive a subscription to <i>Experience Life</i>. 
	Published 10 times per year, it&#39;s our highly regarded healthy way of life magazine.</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">Member Advantage</span></b><br>
	You now have access to Life Time&#39;s easy-to-use member discount program, which offers you exclusive savings at hundreds of partners nationally and locally. 
	Receive discounts on products and services you use every day from national brands to local favorites. 
	<b>Go to myLT.com to view all the Member Advantage partners</b>
	</span>
	</p>
	
<p><span style="font-size: 11pt;">
	Our goal is to empower you with the tools you need to maintain good health. 
	We look forward to assisting you in your healthy way of life journey. 
	Contact us at totalhealth@lifetimefitness.com if you have questions regarding this wellness benefit.
	</span>
	</p>

<p><span style="font-size: 11pt;">
	Sincerely,<br>
	' + @ReimbursementProgramName + ' and Life Time Fitness
	</span>
	</p>
	
<br>

<p><span style="font-size: 10pt;">
	*If at a later date you become ineligible for your company&#39;s wellness benefit, at that time you will be charged the standard monthly dues, including a subscription to <i>Experience Life</i>. 
	Membership dues, prices and fees are subject to change at any time. 
	Service or downgrade fees may apply to membership changes. 
	Cannot be combined with any other discounts. 
	</span>
	</p>
'
--Existing Members without myLT Accounts
     WHEN @EnrollmentType = 'ExistingMemberNoMylt'
     THEN '
<p><span style="font-size: 12pt">
	Dear ' + @FirstName + ',
	</span>
	</p>

<p><b><span style="font-size: 12pt">
	Announcing your new wellness benefit brought to you by ' + @ReimbursementProgramName + ', in partnership with Life Time Fitness. 
	</span></b>
	</p>

<p><span style="font-size: 11pt">
	As a Life Time Fitness member, you&#39;ll receive a <b>credit on your monthly dues*</b> as part of your company&#39;s wellness program. 
	In addition the program includes personalized health and fitness programs, tools and reliable information prepared by the experts at Life Time Fitness and Mayo Clinic. 
	</span>
	</p>

<p><span style="font-size: 12pt">
	Take a minute to review all the offerings included in your new wellness benefit:
	</span>
	</p>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">myLT.com Online Personal Account</span></b><br>
	Connect to all the components of your wellness benefit in one convenient place. 
	It&#39;s continually updated with relevant health information based on your interests. 
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b><a href = "' + @URL + '">Click here</a> or paste ' + @URL + ' in your browser window to activate your account, if you don&#39;t already have one</b></li>
	<li><b>You&#39;ll create a unique username and password to build your account.</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">RiskPoint Health Screening</span></b><br>
	A simple blood test gives you a look at more than 40 important health points such as cholesterol, glucose, triglycerides, protein and complete blood count. 
	A detailed personal report will explain your results and provide you with educational materials.  
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b>To schedule, go to myLT.com > my wellness benefit  > RiskPoint Health Screening</b></li>
	<li><b>Use the Username and Password you created on myLT.com</b></li>
	<li><b>To receive your free results, complete the screening within 60 days</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">Mayo Clinic Tools & Trackers</span></b><br>
	A personalized and interactive health management resource that combines smart technology, Mayo Clinic expertise and personalized resources, tools and trackers. 
	Complete a survey to create a Personal Action Plan, which will guide you to informational and motivational resources based on your specific needs and interests.
	<ul style = "margin-bottom: 0px; margin-top: 0px;">
	<li><b>Log into myLT.com and go to my wellness benefit > Mayo Clinic Tools & Trackers</b></li>
	<li><b>Enter your Life Time Fitness Member # in the Unique ID field(In myLT.com, click on your picture or name to get your #)</b></li>
	</ul>
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;"><i>Experience Life</i> Magazine</span></b><br>
	You&#39;ll automatically receive a subscription to <i>Experience Life</i>. 
	Published 10 times per year, it&#39;s our highly regarded healthy way of life magazine.
	</span>
	</p>
	
<br>

<p style="margin: 0in 0in 0pt 0.3in; line-height: normal;"><span style="font-size: 11pt;">
	<b><span style="font-size: 11pt;">Member Advantage</span></b><br>
	You now have access to Life Time&#39;s easy-to-use member discount program, which offers you exclusive savings at hundreds of partners nationally and locally. 
	Receive discounts on products and services you use every day from national brands to local favorites. 
	<b>Go to myLT.com to view all the Member Advantage partners</b>
	</span>
	</p>
	
<p><span style="font-size: 11pt;">
	Our goal is to empower you with the tools you need to maintain good health. 
	We look forward to assisting you in your healthy way of life journey. 
	Contact us at totalhealth@lifetimefitness.com if you have questions regarding this wellness benefit.
	</span>
	</p>

<p><span style="font-size: 11pt;">
	Sincerely,<br>
	' + @ReimbursementProgramName + ' and Life Time Fitness
	</span>
	</p>
	
<br>

<p><span style="font-size: 10pt;">
	*If at a later date you become ineligible for your company&#39;s wellness benefit, at that time you will be charged the standard monthly dues, including a subscription to <i>Experience Life</i>. 
	Membership dues, prices and fees are subject to change at any time. 
	Service or downgrade fees may apply to membership changes. 
	Cannot be combined with any other discounts. 
	</span>
	</p>
'
END

--Send Email
EXEC msdb.dbo.sp_send_dbmail 
		@recipients    = @EmailAddress,
		@subject       = @SubjectLine,
		@body          = @EmailText,
		@profile_name  = 'Lifetime',
		@body_format   = 'HTML'


--Get Next Member
FETCH NEXT
FROM  MemberCursor
INTO  @MemberID, 
	  @FirstName, 
	  @EmailAddress,
	  @MemberToken,
	  @ReimbursementProgramName,
	  @EnrollmentType

END

CLOSE MemberCursor
DEALLOCATE MemberCursor


--Set the End Time for the Job
UPDATE vLastProcessedDateTime
SET LastProcessedDateTime = @CurrentHour
WHERE Description = 'New Member Corporate Flex Email'

DROP TABLE #NewMembers

END


