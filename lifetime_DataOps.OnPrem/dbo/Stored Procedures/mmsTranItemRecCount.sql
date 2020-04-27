
CREATE PROCEDURE [dbo].[mmsTranItemRecCount] @RowCount INT OUTPUT 
AS
BEGIN

DECLARE @CompareDate DATETIME
SET @CompareDate = CAST(CONVERT(VARCHAR,GETDATE(),101) AS DATETIME)

SELECT @RowCount = COUNT(*)
  FROM vTranItem
 WHERE InsertedDateTime >= @CompareDate

END
