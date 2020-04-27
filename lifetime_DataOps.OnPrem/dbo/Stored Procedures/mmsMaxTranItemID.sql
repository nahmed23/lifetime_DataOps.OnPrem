
CREATE PROCEDURE [dbo].[mmsMaxTranItemID]  @MaxTranItemID INT OUTPUT AS
SELECT @MaxTranItemID = MAX(TranItemID)
FROM vTranItem


