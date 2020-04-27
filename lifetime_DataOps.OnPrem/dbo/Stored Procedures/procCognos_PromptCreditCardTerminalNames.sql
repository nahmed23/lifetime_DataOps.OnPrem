
CREATE   PROC [dbo].[procCognos_PromptCreditCardTerminalNames]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


Select Distinct (Name) AS TerminalName
From vPTCreditCardTerminal


END

