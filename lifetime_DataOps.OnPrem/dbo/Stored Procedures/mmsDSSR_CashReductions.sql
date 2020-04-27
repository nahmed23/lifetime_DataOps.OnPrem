









--THIS PROCEDURE RETURNS ALL  POS IF or Add-on transaction for members who are 
--30 day cancellations or downgrades

CREATE                PROCEDURE dbo.mmsDSSR_CashReductions(
  @ClubList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
  SELECT C.ClubName, C.ClubID
    INTO #Clubs
    FROM dbo.vClub C 
    JOIN #tmpList tmp 
         ON tmp.StringField = C.ClubName
         OR tmp.StringField = 'All'


   SELECT DISTINCT DC.ClubID,DC.ClubName,MembershipID,EventDate ,EventDescription ,Today_Flag,
          EventTranItemID,EventItemAmount,MMSTranID,MemberID,TranReasonDescription,JoinDate,
          PostDateTime,CommEmplFirstName, CommEmplLastName,ProductDescription,CommissionCount, TranItemID,ItemAmount, 
          PrimaryFirstName, PrimaryLastName,TranType,CommEmployeeID,VR.Description AS MembershipRegion
   FROM dbo.vDSSRCashReductionSummary DC
         JOIN #Clubs C 
           ON DC.ClubID = C.ClubID
         JOIN vClub MC
           ON DC.ClubID = MC.ClubID
         JOIN vValRegion VR
           ON VR.ValRegionID = MC.ValRegionID
  
  DROP TABLE #tmpList
  DROP TABLE #Clubs

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END












