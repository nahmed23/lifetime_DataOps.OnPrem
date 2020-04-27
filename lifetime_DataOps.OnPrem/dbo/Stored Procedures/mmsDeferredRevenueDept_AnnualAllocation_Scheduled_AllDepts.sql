

---------------------------  mmsDeferredRevenueDept_AnnualAllocation_Scheduled_AllDepts  ---------------------------
CREATE PROCEDURE [dbo].[mmsDeferredRevenueDept_AnnualAllocation_Scheduled_AllDepts] AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--	============================================================================
--	Object:			dbo.mmsDeferredRevenueDept_AnnualAllocation_Scheduled_AllDepts
--	Author:			
--	Create Date:	
--	Description:	
--	Modified:		
--	EXEC mmsDeferredRevenueDept_AnnualAllocation_Scheduled_AllDepts
--  6/22/2010 MLL Replaced "Dance and Martial Arts" with "Dance", "Martial Arts" and "Mixed Combat Arts" 
--                on parameter call
--  1/24/2011 BSD Replaced 'Aquatics|Tennis|Pro Shop|Youth Fitness|Camps|Birthday Parties|Yoga|Events|Rockwall|Dance|Martial Arts|Mixed Combat Arts|Basketball|Squash - Racquetball'
--                parameter with 'All' - new code in called procedure RR427
-- ===========================================================================

	-- Report Logging
	DECLARE @Identity AS INT
	INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
	SET @Identity = @@IDENTITY

    ------ Define report year
	DECLARE @Year as int
	-- January 1st
	IF (DAY(GETDATE()) = 1 and MONTH(GETDATE())=1)  
		SET @Year = YEAR(GETDATE()-1)	
	ELSE
		SET @Year = YEAR(GETDATE())	


EXEC dbo.mmsDeferredRevenueDept_AnnualAllocation @Year,'All'

	

	-- Report Logging
	UPDATE HyperionReportLog
	SET EndDateTime = getdate()
	WHERE ReportLogID = @Identity
END
