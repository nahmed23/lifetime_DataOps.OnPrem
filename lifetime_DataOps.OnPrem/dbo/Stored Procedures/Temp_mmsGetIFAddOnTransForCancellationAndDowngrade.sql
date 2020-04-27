






--THIS PROCEDURE RETURNS ALL  POS IF or Add-on transaction for members who are 
--30 day cancellations or downgrades

Create             PROCEDURE dbo.Temp_mmsGetIFAddOnTransForCancellationAndDowngrade(
  @ClubList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
  SELECT C.ClubName, C.ClubID, C.ClubActivationDate
    INTO #Clubs
    FROM dbo.vClub C 
    JOIN #tmpList tmp 
         ON tmp.StringField = C.ClubName
         OR tmp.StringField = 'All'

   -----
   -----  This is the query I used to find all of my "30 Day Downgrade" Membership IDs
   -----

   SELECT AL6.ClubID, AL6.ClubName, AL1.MembershipID, AL4.Description AS EventDescription, 
          AL2.ItemAmount As EventItemAmount, AL1.PostDateTime AS EventDate, AL2.TranItemID As EventTranItemID, 
          AL5.Description AS ProductDescription, AL1.MemberID, AL6.ClubActivationDate
   INTO #DownGrade
   FROM dbo.vMMSTran AL1 JOIN dbo.vTranItem AL2 ON AL2.MMSTranID=AL1.MMSTranID
                         JOIN dbo.vValTranType AL3 ON AL3.ValTranTypeID=AL1.ValTranTypeID
                         JOIN dbo.vReasonCode AL4 ON AL4.ReasonCodeID=AL1.ReasonCodeID 
                         JOIN dbo.vProduct AL5 ON AL5.ProductID=AL2.ProductID
                         JOIN dbo.vMembership AL7 ON AL7.MembershipID=AL1.MembershipID
                         JOIN #Clubs AL6 ON AL7.ClubID=AL6.ClubID
   WHERE (AL3.Description='Refund' AND AL1.TranVoidedID IS NULL AND 
         (AL1.PostDateTime>= @FirstOfMonth AND AL1.PostDateTime<@ToDay) AND 
          AL4.Description='30 Day Downgrade' AND AL2.ProductID IN (88, 89, 286))


   -----
   -----  This is the query I used to find all of my "30 Day Cancellation","30 Day Non-Paid and
   -----  "30-Day Duplicate" Membership IDs
   -----

   SELECT AL1.ClubID, AL4.ClubName, AL1.MembershipID, AL3.MemberID, AL1.ExpirationDate As EventDate,
          AL2.Description As EventDescription, AL3.JoinDate, AL4.ClubActivationDate
   INTO #Cancellation
   FROM dbo.vMembership AL1 JOIN dbo.vValTerminationReason AL2 ON AL1.ValTerminationReasonID=AL2.ValTerminationReasonID
                            JOIN dbo.vMember AL3 ON AL3.MembershipID=AL1.MembershipID
                            JOIN dbo.#Clubs AL4 ON AL4.ClubID=AL1.ClubID
   WHERE (AL2.ValTerminationReasonID IN(21,41,42) AND 
         (AL1.ExpirationDate>=@FirstOfMonth AND AL1.ExpirationDate<@ToDay) AND 
         AL3.ValMemberTypeID=1)


   SELECT MembershipID, ClubActivationDate INTO #T1 FROM #DownGrade
   INSERT INTO #T1(MembershipID, ClubActivationDate)
   SELECT MembershipID, ClubActivationDate FROM #Cancellation

   -----
   -----  This is the query to gather all of the Initiation Fee and Membership Add on product sales for the above collected memberships
   -----

   SELECT DISTINCT CASE 
          WHEN AL10.ClubID IS NULL THEN AL9.ClubID
          ELSE AL10.ClubID END ClubID,
          CASE 
          WHEN AL10.ClubName IS NULL THEN AL9.ClubName
          ELSE AL10.ClubName END ClubName,
          AL1.MembershipID,
          CASE 
          WHEN AL9.EventDate IS NULL THEN AL10.EventDate
          ELSE AL9.EventDate END  EventDate ,
          CASE 
          WHEN AL9.EventDescription IS NULL THEN AL10.EventDescription
          ELSE AL9.EventDescription END  EventDescription ,
          CASE
          WHEN (AL9.EventDate IS NULL AND AL10.EventDate >=@Yesterday AND AL10.EventDate < @ToDay)
               OR (AL10.EventDate IS NULL AND AL9.EventDate >=@Yesterday AND AL9.EventDate < @ToDay)
          THEN 1
          ELSE 0
          END Today_Flag,
          AL9.EventTranItemID,AL9.EventItemAmount,
          AL1.MMSTranID, AL1.MemberID, AL2.Description As TranReasonDescription, AL10.JoinDate,
          AL1.PostDateTime, AL6.FirstName AS CommEmplFirstName, AL6.LastName AS CommEmplLastName, 
          AL4.Description AS ProductDescription, AL7.CommissionCount, AL3.TranItemID, AL3.ItemAmount, 
          AL8.FirstName AS PrimaryFirstName, AL8.LastName AS PrimaryLastName, VTT.Description AS TranType,
          AL6.EmployeeID AS CommEmployeeID
   FROM dbo.vMMSTran AL1 JOIN dbo.vReasonCode AL2 ON AL1.ReasonCodeID=AL2.ReasonCodeID
                         JOIN dbo.vTranItem AL3 ON AL1.MMSTranID=AL3.MMSTranID
                         JOIN dbo.vProduct AL4 ON AL3.ProductID=AL4.ProductID
                         JOIN dbo.vMember AL8 ON AL8.MembershipID=AL1.MembershipId
                         JOIN #T1 T ON AL1.MembershipID = T.MembershipID
                         JOIN dbo.vValTranType VTT ON AL1.ValTranTypeID=VTT.ValTranTypeID
                         LEFT OUTER JOIN dbo.vSaleCommission AL5 ON (AL3.TranItemID=AL5.TranItemID) 
                         LEFT OUTER JOIN dbo.vEmployee AL6 ON (AL5.EmployeeID=AL6.EmployeeID) 
                         LEFT OUTER JOIN dbo.vCommissionSplitCalc AL7 ON (AL3.TranItemID=AL7.TranItemID)
                         LEFT OUTER JOIN #DownGrade AL9 ON AL1.MembershipID = AL9.MembershipID
                         LEFT OUTER JOIN #Cancellation AL10 ON AL1.MembershipID = AL10.MembershipID
   WHERE (AL1.TranVoidedID IS NULL AND AL1.PostDateTime > (DateAdd(d,-365,@ToDay))
   AND AL3.ProductID IN (88, 89, 286) AND AL8.ValMemberTypeID=1)
  --------
   -------
  
  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #DownGrade
  DROP TABLE #Cancellation

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








