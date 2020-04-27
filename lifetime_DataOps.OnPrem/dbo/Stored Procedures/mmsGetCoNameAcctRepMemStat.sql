

--
--procedure retrieves company names for selected acct reps and membership status
--parameters: account rep initials and membership staus description ids
--

CREATE PROCEDURE dbo.mmsGetCoNameAcctRepMemStat (
  @MemStatusList VARCHAR(8000),
  @ARList VARCHAR(8000)
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
  
  EXEC procParseStringList @MemStatusList
  CREATE TABLE #MemStatusList (StatusDesc VARCHAR(50))
  INSERT INTO #MemStatusList (StatusDesc) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

  EXEC procParseStringList @ARList
  CREATE TABLE #ARList (AccountRepInitials VARCHAR(50))
  INSERT INTO #ARList (AccountRepInitials) SELECT StringField FROM #tmpList

  SELECT CO.CompanyID, CO.CompanyName, CO.CorporateCode, 
         COUNT (DISTINCT (M.MembershipID)) AS MembershipID, CO.AccountRepInitials 
    FROM dbo.vCompany CO
    JOIN dbo.vMembership M
         ON CO.CompanyID = M.CompanyID
    JOIN #ARList AR
         ON CO.AccountRepInitials = AR.AccountRepInitials
    JOIN dbo.vValMembershipStatus VMSS 
         ON M.ValMembershipStatusID = VMSS.ValMembershipStatusID
    JOIN #MemStatusList MSL
         ON VMSS.Description = MSL.StatusDesc
   GROUP BY CO.CompanyID, CO.CompanyName, CO.CorporateCode, CO.AccountRepInitials
   ORDER BY CO.CompanyName

  DROP TABLE #ARList
  DROP TABLE #MemStatusList
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


