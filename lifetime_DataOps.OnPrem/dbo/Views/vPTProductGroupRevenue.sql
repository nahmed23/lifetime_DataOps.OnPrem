﻿CREATE VIEW dbo.vPTProductGroupRevenue AS 
SELECT PTProductGroupRevenueID,ClubID,EmployeeID,PayPeriod,SalesRevenueTotal,ServiceRevenueTotal,ValPTProductGroupID,InsertUser,BatchID,UpdatedUser
FROM Report_MMS.dbo.PTProductGroupRevenue WITH(NOLOCK)
