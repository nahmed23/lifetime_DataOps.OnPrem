

-- =============================================
-- Object:			mmsGetPartners_CorpFlex
-- Author:			Greg Burdick
-- Create date: 	9/18/2009 per RR396; deploying via dbcr_5046 on 9/23/2009;
-- Description:		Returns a result set of Partners associated with the Partner Program 'Corporate Flex'
--
-- Modified date:	
--
-- EXEC mmsGetPartners_CorpFlex
-- =============================================

CREATE    PROC [dbo].[mmsGetPartners_CorpFlex]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT DISTINCT 
RP.ReimbursementProgramID,
RP.ReimbursementProgramName AS [Partner],
RPIF.ReimbursementProgramIdentifierFormatID,
RPIF.Description AS [Program]

FROM vReimbursementProgram RP
JOIN vReimbursementProgramIdentifierFormat RPIF ON RP.ReimbursementProgramID = RPIF.ReimbursementProgramID

WHERE RPIF.Description = 'Corporate Flex'


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
