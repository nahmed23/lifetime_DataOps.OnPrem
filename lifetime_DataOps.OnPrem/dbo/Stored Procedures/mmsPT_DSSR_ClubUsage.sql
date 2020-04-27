


--
-- Returns Total check-in counts by club Month to date
--

CREATE           PROC dbo.mmsPT_DSSR_ClubUsage 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @StartDate AS DATETIME
  DECLARE @EndDate AS DATETIME
  DECLARE @ReportDate AS DATETIME
  
  SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
  SET @EndDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
  SET @ReportDate = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(d,-1,GETDATE()),110),110)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

          SELECT C.ClubID, C.ClubName,Count(MU.MemberUsageID)As TotalCheckIns,
          @StartDate AS PeriodStart,@ReportDate AS PeriodEnd, @EndDate AS RunDate
          FROM vMemberUsage MU
               JOIN vClub C
               ON C.ClubID = MU.ClubID
          WHERE MU.UsageDateTime >= @StartDate 
                AND MU.UsageDateTime < @EndDate 
          GROUP BY C.ClubID,C.ClubName
                    

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



