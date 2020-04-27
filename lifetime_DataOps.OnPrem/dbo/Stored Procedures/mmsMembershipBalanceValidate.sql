

-- This procedure verifies that the MembershipBalance is correct after running EFT.

CREATE PROCEDURE [dbo].[mmsMembershipBalanceValidate]
								@RowsProcessed int output, 
								@Description  varchar(80) output
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON 

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

DECLARE @Count INT
DECLARE @DBName VARCHAR(100)
DECLARE @EmailGroup VARCHAR(100)
DECLARE @LoopCount INT
DECLARE @subject VARCHAR (250)

SET @EmailGroup = 'DSchmidt@lifetimefitness.com;ISDataWarehouseSupport@lifetimefitness.com;POneal@lifetimefitness.com'
--SET @EmailGroup = 'IT-TEST'

EXEC mmsMembershipBalanceCheck @Count OUTPUT
SET @LoopCount = 1
WHILE @Count > 0 AND @LoopCount < 10
BEGIN
  SET @LoopCount = @LoopCount + 1
  WAITFOR DELAY '00:01:00'
  EXEC mmsMembershipBalanceCheck @Count OUTPUT        
END
IF @Count > 0 AND @LoopCount = 10
BEGIN
  SELECT @DBName = DB_Name()
  SET @subject = 'MMS MembershipBalances Are Incorrect' + '(Database: ' + @@SERVERNAME + '.' + DB_Name() + ')'
  EXEC msdb.dbo.sp_send_dbmail   @recipients = @EmailGroup
                                ,@copy_recipients = 'RSwenson2@lifetimefitness.com;MVolk@lifetimefitness.com;DBrandsness@lifetimefitness.com;DPlagens@lifetimefitness.com;SSeaberry-Perez@lt.life'
								,@query = 'DECLARE @Count INT EXEC mmsMembershipBalanceCheck @Count'
							    ,@subject = @subject
								,@execute_query_database = @DBName
								,@query_result_width = 500
END

SELECT @RowsProcessed = @Count
SELECT @Description = 'Number of Incorrect MembershipBalances'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
