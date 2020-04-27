

CREATE PROCEDURE [dbo].[mmsUpdateBrioEvnt] AS

BEGIN
   EXEC MNCODB03.Brio8Rep.DBO.Brio8RepTriggerMACMonthlyStatementsEvent
END

