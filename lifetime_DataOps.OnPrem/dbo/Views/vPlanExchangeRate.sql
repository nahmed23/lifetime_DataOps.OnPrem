

CREATE VIEW [dbo].[vPlanExchangeRate]  
AS
SELECT PlanExchangeRateID,
       PlanYear,                                      
       FromCurrencyCode,                                     
       ToCurrencyCode,                                       
       PlanExchangeRate ,
	   InsertedDateTime,                                     
	   InsertUser,                                           
	   BatchID 
FROM PlanExchangeRate 
 WITH (NOLOCK)

