
CREATE PROC [dbo].[procCognos_PT_DSSR_Summary_PenetrationSummary_ByClub_MMS] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

Exec procCognos_PT_DSSR_PenetrationSummary_ByClub_MMS 'Entire PT Division','By Region And Club'

END
