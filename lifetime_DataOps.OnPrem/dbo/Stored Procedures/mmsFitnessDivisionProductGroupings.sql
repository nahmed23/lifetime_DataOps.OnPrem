
CREATE PROC [dbo].[mmsFitnessDivisionProductGroupings]

AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
	Object:			mmsFitnessDivisionProductGroupings
	Author:			Greg Burdick
	Create date: 	11/9/2009 
	Description:	Lists product configuration of Fitness Division products
	Modified date:	12/08/2009 GRB: added 'Garmin' per QC# 4117;
					10/13/2010 BSD: added Old_vs_NewBusiness_TrackingFlag column

	Exec mmsFitnessDivisionProductGroupings
	=============================================	*/


--Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

--Fitness Division products that shows the product id, product description, product group description and pt product description			

SELECT			
	p.ProductID, p.Description [ProductDescription], --p.ValProductStatusID, 		
	vps.Description [ProductStatus],		
--	d.DepartmentID, 		
	d.Description [Department],		
--	PG.ProductGroupID, 		
	VPG.Description [ProductGroupDescription],		
--	PTPG.ValPTProductGroupID, 		
	VPTPG.Description [PtProductGroupDescription], VPTPG.ServiceFlag [PtProdcutGroupServiceFlag],
	p.GLAccountNumber, p.GLSubAccountNumber,
	PG.Old_vs_NewBusiness_TrackingFlag
FROM			
	vProduct p		
	JOIN vValProductStatus vps ON p.ValProductStatusID = vps.ValProductStatusID		
	LEFT JOIN vDepartment d ON p.DepartmentID = d.DepartmentID		
	LEFT JOIN vProductGroup PG ON p.ProductID = PG.ProductID		
	LEFT JOIN vValProductGroup VPG ON VPG.ValProductGroupID = PG.ValProductGroupID		
	LEFT JOIN vPtProductGroup PTPG ON p.ProductID = PTPG.ProductID		
	LEFT JOIN vValPtProductGroup VPTPG ON VPTPG.ValPtProductGroupID = PTPG.ValPtProductGroupID		
WHERE p.DepartmentID IN (9,19,10)			
--	D.Description IN ( 'Personal Training', 'Nutrition Coaching', 'Mind Body')		
	AND p.ValProductStatusID <> 3

UNION
			
SELECT			
	p.ProductID, p.Description [ProductDescription], --p.ValProductStatusID, 		
	vps.Description [ProductStatus],		
--	d.DepartmentID, 		
	d.Description [Department],		
--	PG.ProductGroupID, 		
	VPG.Description [ProductGroupDescription],		
--	PTPG.ValPTProductGroupID, 		
	VPTPG.Description [PtProductGroupDescription], VPTPG.ServiceFlag [PtProdcutGroupServiceFlag],
	p.GLAccountNumber, p.GLSubAccountNumber,
	PG.Old_vs_NewBusiness_TrackingFlag
FROM			
	vProduct p		
	JOIN vValProductStatus vps ON p.ValProductStatusID = vps.ValProductStatusID		
	JOIN vDepartment d ON p.DepartmentID = d.DepartmentID		
	JOIN vProductGroup PG ON p.ProductID = PG.ProductID		
	JOIN vValProductGroup VPG ON VPG.ValProductGroupID = PG.ValProductGroupID		
	LEFT JOIN vPtProductGroup PTPG ON p.ProductID = PTPG.ProductID		
	LEFT JOIN vValPtProductGroup VPTPG ON VPTPG.ValPtProductGroupID = PTPG.ValPtProductGroupID		
WHERE p.DepartmentID = 7 --'Merchandise'
	AND p.ValProductStatusID <> 3		
ORDER BY vps.Description, p.Description		--p.ProductID	

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
