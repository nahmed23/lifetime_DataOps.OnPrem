
--	============================================================================
--	Object:			dbo.mmsDeferredRevenueDept_AnnualAllocation_Scheduled_Aquatics
--	Author:			
--	Create Date:	
--	Description:	
--	Modified:		9/24/2009 GRB: per defect 3719, reverted EXEC command to original state; deploying via dbcr_5070 on 9/28/2009
--					5/21/2009 GRB: per RR372, changed EXECUTED dbo from dbo.mmsDeferredRevenueDept_AnnualAllocation to
--					dbo.mmsDepartmentProgram_Revenue_Qrtly; also added 'All' and quarter string parms; deploying
--					via dbcr_4588 on 6/03/2009
--
--	EXEC mmsDeferredRevenueDept_AnnualAllocation_Scheduled_Aquatics
-- ===========================================================================

CREATE PROCEDURE [dbo].[mmsDeferredRevenueDept_AnnualAllocation_Scheduled_Aquatics] AS
BEGIN
	-- Report Logging
	DECLARE @Identity AS INT
	INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
	SET @Identity = @@IDENTITY

	DECLARE @Year as int
	-- January 1st
	IF (DAY(GETDATE()) = 1 and MONTH(GETDATE())=1)  
		SET @Year = YEAR(GETDATE()-1)	
	ELSE
		SET @Year = YEAR(GETDATE())	

EXEC dbo.mmsDeferredRevenueDept_AnnualAllocation @Year,'Aquatics'						-- originally commented out on 5/21/2009, but re-implemented on 9/24/2009 GRB

	--	EXEC dbo.mmsDepartmentProgram_Revenue_Qrtly @Year,'Aquatics', 'All', '1|2|3|4'	-- 9/24/2009		

	-- Report Logging
	UPDATE HyperionReportLog
	SET EndDateTime = getdate()
	WHERE ReportLogID = @Identity
END
