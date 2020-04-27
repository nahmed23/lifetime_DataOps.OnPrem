
CREATE PROC [dbo].[procCognos_PromptPaymentStatus] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT
ValPaymentStatusID,
Description PaymentStatusDescription,
SortOrder
FROM vValPaymentStatus

END

