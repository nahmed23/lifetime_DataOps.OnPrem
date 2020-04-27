

CREATE VIEW [dbo].[vMonthlyAverageExchangeRate] 
AS
SELECT MonthlyAverageExchangeRateID,
       FirstOfMonthDate,                                     
       EndOfMonthDate,                                       
       FromCurrencyCode,                                     
       ToCurrencyCode,                                       
       MonthlyAverageExchangeRate,
	   InsertedDateTime,                                     
	   InsertUser,                                           
	   BatchID 
FROM MonthlyAverageExchangeRate
 WITH (NOLOCK)
