CREATE VIEW dbo.vGiftCardProductSequence AS 
SELECT Sequence
FROM MMS.dbo.GiftCardProductSequence WITH(NOLOCK)
