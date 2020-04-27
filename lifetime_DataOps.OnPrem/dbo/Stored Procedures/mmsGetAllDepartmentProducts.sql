






--
-- returns all department products, currently displaying in the UI or not
--


CREATE      PROC dbo.mmsGetAllDepartmentProducts 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity int
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY


SELECT D.Description AS DeptDescription, P.ProductID, P.Description AS ProductDescription,
       VMAPG.Description AS MemberProgrammingActivitiesGroup, 
       PG.GLRevenueAccount, PG.GLRevenueSubAccount, P.DisplayUIFlag,PS.Description AS ProductStatusDescription
FROM vDepartment D 
       JOIN vProduct P 
         ON D.DepartmentID=P.DepartmentID
       JOIN vValProductStatus PS
         ON PS.ValProductStatusID = P.ValProductStatusID
       LEFT JOIN vProductGroup PG 
         ON P.ProductID=PG.ProductID 
       LEFT JOIN vValMemberActivitiesProductGroup VMAPG 
         ON PG.ValMemberActivitiesProductGroupID=VMAPG.ValMemberActivitiesProductGroupID

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END







