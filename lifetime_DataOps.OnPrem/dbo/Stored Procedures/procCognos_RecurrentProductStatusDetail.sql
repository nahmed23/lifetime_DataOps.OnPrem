﻿

/*	=============================================
	Object:			procCognos_RecurrentProductStatusDetail	
	EXEC procCognos_RecurrentProductStatusDetail
	=============================================	*/

CREATE PROC [dbo].[procCognos_RecurrentProductStatusDetail]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @ToDay DATETIME
DECLARE @FirstOfMonth DATETIME
DECLARE @FirstOfNextMonth DATETIME

SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)
SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@Today,112),1,6) + '01', 112)
SET @FirstOfNextMonth = DATEADD(mm, 1,@FirstOfMonth)

DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C  
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode
/***************************************/

  SELECT VRP.Description RecurrentProductDescription, 
		 P.Description ProductDescription, 
         MSRP.MembershipID,
         C.ClubName AS MembershipClubName,		 
		 MSRP.ActivationDate as ActivationDate_Sort,
	     Replace(SubString(Convert(Varchar, MSRP.ActivationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MSRP.ActivationDate),5,DataLength(Convert(Varchar, MSRP.ActivationDate))-12)),' '+Convert(Varchar,Year(MSRP.ActivationDate)),', '+Convert(Varchar,Year(MSRP.ActivationDate))) as ActivationDate,
         MSRP.CancellationRequestDate RProductCancellationrequestdate, 
         MSRP.TerminationDate, 
         @ReportRunDateTime AS ReportRunDateTime,         
         VR.Description RegionDescription, M.MemberID, M.FirstName,
         M.LastName, M.ValMemberTypeID, P.ProductID,
         MS.ExpirationDate AS MembershipExpirationDate,
         MS.CancellationRequestDate AS MembershipCancellationRequestDate,
         MA.AddressLine1,MA.AddressLine2,MA.City,S.Abbreviation AS State, MA.Zip,
		-- active recurrent products
         CASE
			-- active memberships
           WHEN 
				VRP.Description in ('Recurrent Products for Non-Terminated Members', 'Recurrent Products for Active Members')
				AND MSRP.ActivationDate <= @Today 
				AND (MSRP.TerminationDate Is Null or MSRP.TerminationDate >=@Today) --include today's date
           THEN 1
			-- expired memberships
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				-- recurrent product is active 
				-- product activation date is actual Activation Date
				AND MSRP.ActivationDate >= MS.ExpirationDate
				AND MSRP.ActivationDate <= @Today 
				AND (MSRP.TerminationDate Is Null or MSRP.TerminationDate >=@Today)
           THEN 1
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				-- recurrent product is active 
				-- product activation date is determined to be the Membership Expiration Date 
				AND MSRP.ActivationDate < MS.ExpirationDate
				AND MS.ExpirationDate <= @Today 
				AND (MSRP.TerminationDate Is Null or MSRP.TerminationDate >=@Today)
           THEN 1
         ELSE 0
         END Active_Flag,

		-- activated this month
         CASE
			-- active memberships
           WHEN 
				VRP.Description in ('Recurrent Products for Non-Terminated Members', 'Recurrent Products for Active Members')
				-- recurrent product is active
				AND MSRP.ActivationDate >= @FirstOfMonth AND MSRP.ActivationDate <= @Today  
				AND (MSRP.TerminationDate Is Null or MSRP.TerminationDate >=@Today) --include today's date
           THEN 1
			-- expired memberships
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				-- recurrent product is active 
				-- product activation date is actual Activation Date
				AND (MSRP.ActivationDate >= MS.ExpirationDate)
				AND (MSRP.ActivationDate >= @FirstOfMonth AND MSRP.ActivationDate <= @Today)
				AND (MSRP.TerminationDate Is Null or MSRP.TerminationDate >=@Today)
           THEN 1
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				-- recurrent product is active 
				-- product activation date is determined to be the Membership Expiration Date 
				AND MSRP.ActivationDate < MS.ExpirationDate
				AND (MS.ExpirationDate >= @FirstOfMonth AND MS.ExpirationDate <= @Today)
				AND (MSRP.TerminationDate Is Null or MSRP.TerminationDate >=@Today)
           THEN 1
         ELSE 0
         END Activated_ThisMonth,
		
		-- terminated MTD
         CASE
           WHEN MSRP.TerminationDate >= @FirstOfMonth AND MSRP.TerminationDate < @Today  
           THEN 1
         ELSE 0
         END Termed_MTD,

		-- Yet to terminate this month
         CASE
    		-- all non terminated recurrent products with a termination date between report run date and month end date 
           WHEN 
				VRP.Description in ('Recurrent Products for Non-Terminated Members', 'Recurrent Products for Active Members')
				-- recurrent product is active
				AND MSRP.ActivationDate <= @Today 
				AND MSRP.TerminationDate >= @Today AND MSRP.TerminationDate < @FirstOfNextMonth  
           THEN 1
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				AND MSRP.ActivationDate >= MS.ExpirationDate
				AND MSRP.ActivationDate <= @Today 
				AND MSRP.TerminationDate >= @Today AND MSRP.TerminationDate < @FirstOfNextMonth  
           THEN 1
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				AND MSRP.ActivationDate < MS.ExpirationDate
				-- product activation date is determined to be the Membership Expiration Date 
				AND MS.ExpirationDate <= @Today 
				AND MSRP.TerminationDate >= @Today AND MSRP.TerminationDate < @FirstOfNextMonth  
           THEN 1
         ELSE 0
         END YetToTerm_ThisMonth,

		-- Set to term future months
         CASE
    		-- all non terminated recurrent products with a termination date on or after 1st of the next month
           WHEN 
				VRP.Description in ('Recurrent Products for Non-Terminated Members', 'Recurrent Products for Active Members')
				-- recurrent product is active
				AND MSRP.ActivationDate <= @Today 
				AND MSRP.TerminationDate >= @FirstOfNextMonth
           THEN 1
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				-- recurrent product is active 
				-- product activation date is actual Activation Date
				AND (MSRP.ActivationDate >= MS.ExpirationDate)
				AND MSRP.ActivationDate <= @Today 
				AND MSRP.TerminationDate >= @FirstOfNextMonth
           THEN 1
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				-- recurrent product is active 
				-- product activation date is determined to be the Membership Expiration Date 
				AND MSRP.ActivationDate < MS.ExpirationDate
				AND MS.ExpirationDate <= @Today 
				AND MSRP.TerminationDate >= @FirstOfNextMonth
           THEN 1
         ELSE 0
         END SetToTerm_FutureMonths,
		 
		 -- set to activate in future
		 CASE
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				AND (MSRP.ActivationDate >= MS.ExpirationDate)
				AND MSRP.ActivationDate > @Today  
           THEN 1
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				AND MSRP.ActivationDate < MS.ExpirationDate
				AND MS.ExpirationDate > @Today 
           THEN 1
           WHEN 
				VRP.Description in ('Recurrent Products for Non-Terminated Members', 'Recurrent Products for Active Members')
				AND MSRP.ActivationDate > @Today 
		   THEN 1
         ELSE 0
         END SetToActivate_InFuture,

         -- filter out recurrent products that never have been activated
		   CASE
			-- expired memberships
           WHEN 
				VRP.Description in ('Magazine', 'Non-Access Card')
				AND MSRP.TerminationDate <= MS.ExpirationDate
           THEN 1
			-- active memberships
--           WHEN 
--				VRP.Description in ('Recurrent Products for Non-Terminated Members', 'Recurrent Products for Active Members')
--	            AND MSRP.TerminationDate Is Null OR MSRP.TerminationDate >= MSRP.ActivationDate 
--           THEN 0
			-- active and expired memberships
           WHEN 
	            MSRP.TerminationDate <= MSRP.ActivationDate 
           THEN 1
		   ELSE 0	
         END RProductTermDate_PriorToActivationDateFlag,
      CASE
           WHEN DATEDIFF(day,MS.ExpirationDate,MSRP.ActivationDate)= 1  
           THEN MS.CancellationRequestDate
         ELSE MSRP.ActivationDate
         END RProduct_JoinDate,
		CTran.ClubName AS TranClubName,
		MSRP.ClubID AS TranClubID,
/******  Foreign Currency Stuff  *********/	   
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   MSRP.Price * #PlanRate.PlanRate as Price	  	   	   
/***************************************/
    INTO #Results
    FROM dbo.vCLUB C
    JOIN dbo.vMembership MS
         ON C.ClubID = MS.ClubID
    JOIN dbo.vMembershipAddress MA
         ON MS.MembershipID = MA.MembershipID
    JOIN dbo.vValState S
         ON MA.ValStateID = S.ValStateID
    JOIN dbo.vMembershipRecurrentProduct MSRP
         ON MS.MembershipID = MSRP.MembershipID
    JOIN dbo.vProduct P
         ON P.ProductID = MSRP.ProductID
	--  count product for the club that entered transaction
	JOIN dbo.vClub CTran
		 ON CTran.ClubID = MSRP.ClubID
/********** Foreign Currency Stuff **********/
 JOIN vValCurrencyCode VCC
       ON CTran.ValCurrencyCodeID = VCC.ValCurrencyCodeID  
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
/*******************************************/
    JOIN dbo.vValRegion VR
         ON CTran.ValRegionID = VR.ValRegionID
    JOIN dbo.vMember M
         ON M.MembershipID = MSRP.MembershipID
    LEFT JOIN dbo.vValRecurrentProductType VRP
         ON P.ValRecurrentProductTypeID = VRP.ValRecurrentProductTypeID
   WHERE (MSRP.TerminationDate IS NULL OR
         MSRP.TerminationDate >= DATEADD(day,-32,GETDATE() )) AND
         M.ValMemberTypeID = 1         
		 AND MSRP.Price <> 0								


SELECT   
         RecurrentProductDescription, 
		 ProductDescription, 
         MembershipID,
         MembershipClubName,		 
		 ActivationDate_Sort,
	     ActivationDate,
         RProductCancellationrequestdate, 
         TerminationDate, 
         ReportRunDateTime,         
         RegionDescription, 
         MemberID, 
         FirstName,
         LastName, 
         ValMemberTypeID, 
         ProductID,
         MembershipExpirationDate,
         MembershipCancellationRequestDate,
         AddressLine1,AddressLine2,City, State, Zip,
         Active_Flag, -- active recurrent products
         Activated_ThisMonth, -- activated this month
         Termed_MTD,  -- terminated MTD
		 YetToTerm_ThisMonth, -- Yet to terminate this month
         SetToTerm_FutureMonths, -- Set to term future months		 
		 SetToActivate_InFuture,  -- set to activate in future
         RProductTermDate_PriorToActivationDateFlag,          
         RProduct_JoinDate,
		 TranClubName,
		 TranClubID,
         PlanRate,
         ReportingCurrencyCode,
	     Price,	     
	     Active_Flag - (Yettoterm_Thismonth + Settoterm_Futuremonths) AS Active,
	     Yettoterm_Thismonth+Settoterm_Futuremonths AS PendingTermination,
	     Active_Flag+Settoactivate_Infuture AS Total,
	     CASE WHEN Active_Flag = 1 THEN Price ELSE 0 END AS EstimatedDues	     
	     
FROM #Results

DROP TABLE #PlanRate
DROP TABLE #Results


END

