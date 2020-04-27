
-- =============================================
-- Object:			dbo.mmsClubTerminal
-- Author:			Ruslan Condratiuc
-- Create date: 	October 2008
-- Description:		returns terminals for a list of Clubs
-- Parameters:		a list of club ids
-- Modified date:	
-- Release date:	6/18/2008 dbcr_3274
-- Exec mmsClubTerminal 
-- =============================================

CREATE  PROC [dbo].[mmsClubTerminal] 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY



SELECT DISTINCT 
	VCCTL.Description AS ClubTerminal, 
	VCCTL.ValCreditCardTerminalLocationID AS TerminalLocationID,
	PTCCT.ClubID  
FROM vValCreditCardTerminalLocation VCCTL
INNER JOIN vPTCreditCardTerminal PTCCT 
	ON PTCCT.ValCreditCardTerminalLocationID = VCCTL.ValCreditCardTerminalLocationid
	AND PTCCT.DrawerID is null
INNER JOIN vTerminalArea TA 
	ON TA.TerminalAreaID = PTCCT.TerminalAreaID 
	AND ExcludeFromDrawer = 1
ORDER BY VCCTL.Description 


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

