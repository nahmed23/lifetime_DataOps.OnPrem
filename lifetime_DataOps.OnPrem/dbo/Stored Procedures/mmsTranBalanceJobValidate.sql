
------------------------------------------------ dbo.mmsTranBalanceJobValidate
-- This procedure verifies that the MMSTranBalanceJob completed
CREATE PROCEDURE [dbo].[mmsTranBalanceJobValidate]
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON 


  DECLARE @TranBalanceInsertedDate DATETIME 

  SELECT @TranBalanceInsertedDate = ISNULL(MAX(InsertedDateTime),'JAN 01 2000') FROM vTranBalance

  IF NOT(
         (
          ((SELECT COUNT(DISTINCT MembershipID) FROM vTranBalance) + 100)
          >=
          (SELECT COUNT(*) FROM vMembership WHERE ISNULL(InsertedDateTime,'2000-01-01') < (GETDATE() - 1))
         )
         AND
         (
          CONVERT(VARCHAR,GETDATE(),101)
          =
          CONVERT(VARCHAR,@TranBalanceInsertedDate,101)
         )
        )
  BEGIN
    RAISERROR ('TranBalance job did not complete',1,1)
  END

                                                 -- the application uses a 1
                                                 -- to represent success
  RETURN 1

END
