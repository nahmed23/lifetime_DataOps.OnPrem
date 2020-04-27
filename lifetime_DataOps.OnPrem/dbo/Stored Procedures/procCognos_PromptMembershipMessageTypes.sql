
CREATE PROC [dbo].[procCognos_PromptMembershipMessageTypes] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT
ValMembershipMessageTypeID,
Description,
SortOrder,
AutoCloseFlag,
ValMessageSeverityID,
Abbreviation
FROM vValMembershipMessageType


END
