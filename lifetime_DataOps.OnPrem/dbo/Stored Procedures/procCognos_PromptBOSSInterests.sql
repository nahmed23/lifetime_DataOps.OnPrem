
CREATE PROC [dbo].[procCognos_PromptBOSSInterests] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

 IF 1=0 BEGIN
       SET FMTONLY OFF
     END


SELECT ID,short_desc, long_desc
-----FROM [Sandbox_Int].[rep].[BOSS_Interests]     -------  Note: Comment out for PROD
FROM [BOSS].[dbo].[interest]              -------  Note: Comment out for Dev/QA
ORDER BY long_desc



END
