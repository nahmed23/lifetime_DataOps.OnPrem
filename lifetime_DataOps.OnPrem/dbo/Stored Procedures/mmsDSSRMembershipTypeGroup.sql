




--
-- This procedure will return MembershipTypes grouped by based on DSSR requirements
--


CREATE     PROC dbo.mmsDSSRMembershipTypeGroup 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT P.ProductID MembershipTypeID,P.Description MembershipType,
         CASE WHEN P.Description Like '%Fitness%' OR P.Description Like '%Zero%'
          THEN 'Fitness'
         WHEN P.Description Like '%Sports%'
            THEN 'Sports'
         WHEN P.Description Like '%Express%'
            THEN 'Express'
         WHEN P.Description Like '%Upgrade%'
            THEN 'Upgrade'
         WHEN P.Description Like '%Elite%' OR P.Description Like '%Executive%'
              OR P.Description Like '%Emeritus%'OR P.Description Like '%All Access%'
            THEN 'All Access'
         ELSE 'Other'
         END DSSRMembershipTypeGroup
  FROM vProduct P JOIN vMembershipType M ON P.ProductID = M.ProductID
  ORDER BY DSSRMembershipTypeGroup

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




