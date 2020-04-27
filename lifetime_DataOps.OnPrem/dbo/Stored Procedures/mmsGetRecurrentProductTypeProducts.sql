
-- =============================================
-- Object:			dbo.mmsGetRecurrentProductTypeProducts
-- Author:			Greg Burdick
-- Create date: 	6/5/2008
-- Release date:	6/11/2008 dbcr_3274
-- Description:		This procedure provides a dynamic list of Recurrent Product Types.
-- Modified date:	
-- 	
-- EXEC mmsGetRecurrentProductTypeProducts
-- =============================================

CREATE	PROCEDURE [dbo].[mmsGetRecurrentProductTypeProducts] 
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT vrpt.ValRecurrentProductTypeID, vrpt.Description, vrpt.SortOrder,
	p.ProductID, p.DepartmentID, p.Name, p.Description, p.DisplayUIFlag,
	p.ValProductStatusID
  FROM vValRecurrentProductType vrpt 
	JOIN vProduct p ON vrpt.ValRecurrentProductTypeID = p.ValRecurrentProductTypeID

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity


END
