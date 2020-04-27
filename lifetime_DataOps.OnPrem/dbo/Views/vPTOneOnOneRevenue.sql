
CREATE VIEW dbo.vPTOneOnOneRevenue
AS
SELECT     PTOneOnOneRevenueID, ClubID, EmployeeID, ProductID, PayPeriod, SalesTotal, ServiceRevenueTotal, InsertedDateTime, InsertUser, BatchID
FROM         dbo.PTOneOnOneRevenue

