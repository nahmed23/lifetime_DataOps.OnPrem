CREATE VIEW dbo.vGLAccount AS 
SELECT GLAccountID,RevenueGLAccountNumber,RefundGLAccountNumber,InsertedDateTime,UpdatedDateTime,DiscountGLAccount
FROM MMS.dbo.GLAccount WITH(NOLOCK)
