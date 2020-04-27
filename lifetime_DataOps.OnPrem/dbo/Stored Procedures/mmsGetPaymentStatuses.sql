
-- =============================================
-- Object:			dbo.mmsGetPaymentStatuses
-- Author:			Greg Burdick
-- Create date: 	2/9/2009 via dbcr_4170 deploying 2/18/2009
-- Description:		Returns a result set of Payment Status values
-- Modified date:	
-- Exec mmsGetPaymentStatuses
-- =============================================


CREATE  PROC [dbo].[mmsGetPaymentStatuses]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT ValPaymentStatusID, Description, SortOrder
FROM dbo.vValPaymentStatus
ORDER BY SortOrder

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
