


/*
  Procedure looks for anyone who was added within the last hour and sends
  a welcome email.  A specific MemberID can be provided when running the 
  script to force an email to be sent.  
  
  --Base URL stays the same, but anything after ?event is interchangable
  Prod URL: https://mylt.lifetimefitness.com/index.cfm?event=general.autoRegister&strMemberkey=
  Test URL: https://mntwweb01.ltfinc.net:8081/index.cfm?event=general.autoRegister&strMemberkey=

*/

CREATE PROCEDURE [dbo].[mmsNewMembermyLTEmail] (
	@ProvidedMemberID INT = NULL
	)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @MemberID INT
DECLARE @MemberName VARCHAR(110)
DECLARE @AdvisorName VARCHAR(110)
DECLARE @URL VARCHAR(200)
DECLARE @URL1 VARCHAR(200)
DECLARE @URL2 VARCHAR(200)
DECLARE @EmailAddress VARCHAR(140)
DECLARE @SubjectLine VARCHAR(150)
DECLARE @EmailText VARCHAR(MAX)
DECLARE @Today DATETIME
DECLARE @CurrentHour DATETIME
DECLARE @LastHour DATETIME
DECLARE @InsertedDateTime DATETIME
DECLARE @ClubID INT
DECLARE @CorpFlex INT
CREATE TABLE #NewMembers (MemberID INT,InsertedDateTime datetime,ClubID INT)

SET @Today = CONVERT(VARCHAR(11),GETDATE())
SET @CurrentHour = DATEADD(HH,DATEPART(HH,GETDATE()),CONVERT(VARCHAR(11),GETDATE()))
SELECT @LastHour = LastProcessedDateTime
FROM vLastProcessedDateTime
WHERE Description = 'New Member myLT Email'

SELECT @CorpFlex = ProductID
FROM vProduct
WHERE Description = 'Corporate Flex'

IF @ProvidedMemberID IS NULL 
BEGIN
	INSERT INTO #NewMembers
	SELECT DISTINCT m.MemberID,ms.InsertedDateTime,ms.ClubID
	FROM vMember m
	JOIN vMembership ms
	  ON ms.MembershipID = m.MembershipID
	WHERE m.MemberToken IS NOT NULL
	  AND m.ActiveFlag = 1
	  AND ms.ActivationDate IS NOT NULL
	  AND ms.ValMembershipStatusID <> 1
	  AND ms.AdvisorEmployeeID IS NOT NULL
	  AND m.ValMemberTypeID <> 4
	  AND m.EmailAddress IS NOT NULL
	  AND m.EmailAddress LIKE '%@%.%'
	  AND m.InsertedDateTime >= @LastHour
	  AND m.InsertedDateTime < @CurrentHour
      AND ms.MembershipTypeID <> @CorpFlex
END
ELSE 
BEGIN
	INSERT INTO #NewMembers 
	SELECT MemberID,ms.InsertedDateTime,ms.ClubID
	FROM vMember m
	JOIN vMembership ms
	  ON ms.MembershipID = m.MembershipID
	WHERE m.MemberToken IS NOT NULL
	  AND m.ActiveFlag = 1
	  AND ms.ValMembershipStatusID <> 1
	  AND ms.AdvisorEmployeeID IS NOT NULL
	  AND m.ValMemberTypeID <> 4
	  AND m.EmailAddress IS NOT NULL
	  AND m.EmailAddress LIKE '%@%.%'
	  AND m.MemberID = @ProvidedMemberID
      AND ms.MembershipTypeID <> @CorpFlex
END

--Create Cursor to loop through each Member
DECLARE MemberCursor
CURSOR FOR
   SELECT MemberID,InsertedDateTime,ClubID
   FROM #NewMembers

OPEN MemberCursor

FETCH NEXT
FROM  MemberCursor
INTO  @MemberID,@InsertedDateTime,@ClubID

WHILE @@FETCH_STATUS = 0

BEGIN

     SELECT @MemberName  = m.FirstName, 
	        @AdvisorName = e.FirstName + ' ' + e.LastName,
	        @SubjectLine = 'Welcome to Life Time – activate myLT.com today',
	        @URL = 'https://mylt.lifetimefitness.com/index.cfm?event=general.autoRegister&strMemberkey=' + master.dbo.fn_varbintohexstr (m.MemberToken),
            @EmailAddress = m.EmailAddress
       FROM vMember m
       JOIN vMembership ms
         ON ms.MembershipID = m.MembershipID
       JOIN vEmployee e
         ON e.EmployeeID = ms.AdvisorEmployeeID
      WHERE m.MemberID = @MemberID

--LOOK FOR MEMBERS THAT DON'T HAVE MyLT ACCOUNT
IF (SELECT COUNT(*) FROM tmpLTFUserIdentity WHERE Member_ID = @MemberID) = 0
BEGIN


      SET @EmailText = '<p>Welcome to Life Time Fitness!</p>

          <p>Activate your account now by signing in at <a href = www.mylt.com>myLT.com</a>. Then start enjoying all the benefits your Life Time membership has to offer.</p>

          <p>Manage your account, explore areas of your club that interest you and get great deals on dining, travel, retail and more through our Member Advantage program.</p> 

          <p>It&#39;s quick and easy. <a href = "' + @URL + '">Click here</a> to get started or paste this URL in your browser window: ' + @URL + '</p>

          <p>Sincerely,</p>

          <p>' + @AdvisorName + '</p>'

	  --Special Offer for 1st Half of the month
      IF ((@InsertedDateTime >= '2009-08-01') AND (@InsertedDateTime < '2009-08-16'))
      BEGIN 
            SET @URL1 = 'http://www.lifetimefitness.com/voucher/August/index.cfm'
         	SET @SubjectLine = 'Claim your one-month TEAM Training pass and activate your myLT.com account'
         	SET @EmailText = '<p>Welcome to Life Time Fitness!</p>

                              <p>As promised, your new membership starts with a free one-month T.E.A.M. Training pass, good through September 15, 2009. Claim your certificate by clicking <a href = "' + @URL1 + '">here</a> or paste this URL in your browser window: 
http://www.lifetimefitness.com/voucher/August/index.cfm</p>

                             <p>Also complete your myLT.com registration by <a href = "' + @URL + '">clicking here</a> or by copy/pasting this URL in your browser window: ' + @URL + '.  
                                Then start enjoying all the benefits your Life Time membership has to offer.</p>

                             <p>Manage your account, explore areas of your club that interest you and get great deals on dining, travel, retail and more through our Member Advantage program.</p> 


                             <p>Sincerely,</p>

                             <p>' + @AdvisorName + '</p>'
        END

	  --Special Offer for 2nd Half of the month (check for special club specific settings)
      IF ((@InsertedDateTime >= '2009-06-15') AND (@InsertedDateTime < '2009-07-01') AND @ClubID IN(165,188))
      BEGIN 
            SET @URL2 = 'http://www.lifetimefitness.com/voucher/June2/'
         	SET @SubjectLine = 'Claim your $50 Certificate and activate your myLT.com account'
         	SET @EmailText = '<p>Welcome to Life Time Fitness!</p>

                              <p>As promised, your new membership starts with a free $50 certificate for use on select LifeSpa and Salon, Personal Training or Member Activities services, good through July 15, 2009. Claim your certificate by clicking <a href = "' + @URL2 + '">here</a> or paste this URL in your browser window: 
http://www.lifetimefitness.com/voucher/June2/</p>

                             <p>Also complete your myLT.com registration by <a href = "' + @URL + '">clicking here</a> or by copy/pasting this URL in your browser window: ' + @URL + '.  
                                Then start enjoying all the benefits your Life Time membership has to offer.</p>

                             <p>Manage your account, explore areas of your club that interest you and get great deals on dining, travel, retail and more through our Member Advantage program.</p> 


                             <p>Sincerely,</p>

                             <p>' + @AdvisorName + '</p>'
        END

         EXEC msdb.dbo.sp_send_dbmail 
	          @recipients    = @EmailAddress,
              @subject       = @SubjectLine,
              @body          = @EmailText,
	          @profile_name  = 'Lifetime',
	          @body_format   = 'HTML'
END
ELSE IF (SELECT ValMemberTypeID FROM vMember WHERE MemberID = @MemberID) = 1 --IF THE MEMBER ALREADY HAVE MyLT ACCOUNT AND IS PRIMARY MEMBER
BEGIN
	 set     @SubjectLine = 'Welcome to a healthy way of life' 
	 SET @EmailText = '<p>Congratulations </p>

        <p>Welcome to Life Time Fitness!</p>

        <p>Now that you&#39;ve taken the first step toward a healthier way of life by joining Life Time, make sure you get your health and fitness program started on the right foot.  This includes:</p>

        <p>•	Taking advantage of the one free Personal Training session and free FitPoint assessment you are entitled to as a new member</p>

        <p>•	Logging onto <a href = www.mylt.com>myLT.com</a> to explore all of the ways to connect, engage and interact with your club and fellow members  </p>

        <p>•	Exploring our Member Advantage partner discounts that can save you hundreds of dollars annually on purchases you already make</p>

        <p>We look forward to helping you achieve your health and fitness goals.</p>

        <p>Sincerely,</p>

        <p>Life Time </p>'

	  --Special Offer for 1st Half of the month
     IF ((@InsertedDateTime >= '2009-08-01') AND (@InsertedDateTime < '2009-08-16'))
     BEGIN 
            SET @URL = 'https://mylt.lifetimefitness.com/index.cfm?event=general.dspAccountSignIn'
            SET @URL1 = 'http://www.lifetimefitness.com/voucher/August/index.cfm'
        	SET @SubjectLine = 'Claim your one-month TEAM Training pass and explore myLT.com'

	        SET @EmailText = '<p>Welcome to Life Time Fitness!</p>

	            <p>As promised, your new membership starts with a free one-month T.E.A.M. Training pass, good through September 15, 2009. Claim your certificate by clicking <a href = "' + @URL1 + '">here</a> or paste this URL in your browser window: 
http://www.lifetimefitness.com/voucher/August/index.cfm.</p>

<p>Also, sign in to your myLT.com account to explore all of the ways to connect, engage and interact with your club and fellow members.  <a href = "' + @URL + '">Click here</a> or copy/paste this URL in your browser window: 
https://myLT.lifetimefitness.com/index.cfm?event=general.dspAccountSignIn.</p>

	            <p>Manage your account, explore areas of your club that interest you and get great deals on dining, travel, retail and more through our Member Advantage program.</p>

                             <p>Sincerely,</p>

                             <p>' + @AdvisorName + '</p>'

     END
	  --Special Offer for 2nd Half of the month (check for special club specific settings)
      IF ((@InsertedDateTime >= '2009-06-15') AND (@InsertedDateTime < '2009-07-01') AND @ClubID IN(165,188))
     BEGIN 
            SET @URL = 'https://myLT.lifetimefitness.com/index.cfm?event=general.dspAccountSignIn'
            SET @URL2 = 'http://www.lifetimefitness.com/voucher/June2/'
        	SET @SubjectLine = 'Claim your $50 Certificate and explore myLT.com'

	        SET @EmailText = '<p>Welcome to Life Time Fitness!</p>

	            <p>As promised, your new membership starts with a free $50 certificate for use on select LifeSpa and Salon, Personal Training or Member Activities services, good through July 15, 2009. Claim your certificate by clicking <a href = "' + @URL2 + '">here</a> or paste this URL in your browser window: 
http://www.lifetimefitness.com/voucher/June2/.</p>

<p>Also, sign in to your myLT.com account to explore all of the ways to connect, engage and interact with your club and fellow members.  <a href = "' + @URL + '">Click here</a> or copy/paste this URL in your browser window: 
https://myLT.lifetimefitness.com/index.cfm?event=general.dspAccountSignIn.</p>

	            <p>Manage your account, explore areas of your club that interest you and get great deals on dining, travel, retail and more through our Member Advantage program.</p>

                             <p>Sincerely,</p>

                             <p>' + @AdvisorName + '</p>'

     END
	
     EXEC msdb.dbo.sp_send_dbmail 
	      @recipients    = @EmailAddress,
          @subject       = @SubjectLine,
          @body          = @EmailText,
	      @profile_name  = 'Lifetime',
	      @body_format   = 'HTML'
END

FETCH NEXT
FROM  MemberCursor
INTO  @MemberID,@InsertedDateTime,@ClubID

END

CLOSE MemberCursor
DEALLOCATE MemberCursor

IF @ProvidedMemberID IS NULL 
BEGIN
	UPDATE vLastProcessedDateTime
	SET LastProcessedDateTime = @CurrentHour
	WHERE Description = 'New Member myLT Email'
END

DROP TABLE #NewMembers

END
