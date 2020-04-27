

--
-- returns usage detail information for the Medica Processing Brio document
--
-- Parameters: list of corporate codes and a member usage date range
--

CREATE  PROC dbo.mmsMedicaProcessing_UsageDetail (
  @CorpCodeList VARCHAR(2000),
  @StartUsageDate SMALLDATETIME,
  @EndUsageDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))

  CREATE TABLE #Corps (CorpCode VARCHAR(50))
  EXEC procParseStringList @CorpCodeList
  INSERT INTO #Corps (CorpCode) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

  SELECT MU.UsageDateTime, MU.MemberID, M.FirstName,
         M.LastName, CO.CompanyName, MS.MembershipID
    FROM dbo.vMember M
    JOIN dbo.vMemberUsage MU
      ON MU.MemberID = M.MemberID
    JOIN dbo.vValMemberType MT
      ON MT.ValMemberTypeID = M.ValMemberTypeID
    JOIN dbo.vMembership MS
      ON M.MembershipID = MS.MembershipID
    JOIN dbo.vCompany CO
      ON MS.CompanyID = CO.CompanyID
    JOIN #Corps CS
      ON CO.CorporateCode = CS.CorpCode
   WHERE MT.Description = 'Primary' AND 
         MU.UsageDateTime BETWEEN @StartUsageDate AND @EndUsageDate

  DROP TABLE #Corps
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



