
-- ============================================================================
-- Object:            dbo.mmsCorporateMembers
-- Author:        
-- Create Date:    
-- Description:        For Selected companies, returns the Active Primary and 
--                    Junior members so full regular and Junior dues can be calculated
-- Parameter(s):    company
-- Modified:        1/27/2009 GRB: modified code to allow passage of CompanyID instead
--                    of CompanyName;
--                    
-- EXEC mmsCorporateMembers '3490|14941|14942|14943|14944|14945|14946|14947|14948|14949|14950|14951|14952|14953|14954|14955|14956|14957|14958|14959|14960|14961'        
-- EXEC mmsCorporateMembers '3490|14941|14942|14943'
-- SELECT * FROM vCompany ORDER BY CompanyName
-- ===========================================================================

CREATE    PROCEDURE [dbo].[mmsCorporateMembers](
                 @CompanyIDList VARCHAR(2000))

AS

BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT item CompanyID
  INTO #CompanyIDList
  FROM fnParsePipeList(@CompanyIDList)

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

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

SELECT MS.MembershipID,M.FirstName AS MemberFirstName,M.LastName AS MemberLastName,M.MemberID,
    M.ValMemberTypeID,VMT.Description AS MemberType,
    M.AssessJrMemberDuesFlag,VTT.Description AS TaxType,R.Description AS RegionDescription, 
    CO.AccountRepInitials, C.ClubName AS MembershipClub,
--    C.ClubID,
    MS.CancellationRequestDate, 
    M.JoinDate as JoinDate_Sort, 
    Replace(SubString(Convert(Varchar, M.JoinDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, M.JoinDate),5,DataLength(Convert(Varchar, M.JoinDate))-12)),' '+Convert(Varchar,Year(M.JoinDate)),', '+Convert(Varchar,Year(M.JoinDate))) as JoinDate,
    CO.CompanyName,P.Description AS MembershipTypeDescription, 
    VMS.Description AS MembershipStatusDescription,
    CPPT.TaxPercentage,GETDATE() AS ReportDate,
   CASE WHEN M.AssessJrMemberDuesFlag = 1 AND M.ValMemberTypeID = 4 THEN CPPT2.Price * #PlanRate.PlanRate
        ELSE 0
    END MembershipJuniorDues,
   CASE WHEN M.AssessJrMemberDuesFlag = 1 AND M.ValMemberTypeID = 4 THEN CPPT2.Price
        ELSE 0
    END LocalCurrency_MembershipJuniorDues,
   CASE WHEN M.AssessJrMemberDuesFlag = 1 AND M.ValMemberTypeID = 4 THEN CPPT2.Price * #ToUSDPlanRate.PlanRate
        ELSE 0
    END USD_MembershipJuniorDues,
   CASE WHEN CPPT.TaxPercentage IS NULL THEN 0
        ELSE (CPPT.TaxPercentage * .01)
    END AppliedTaxRate,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       CPPT.Price * #PlanRate.PlanRate AS MembershipDues,
       CPPT.Price AS LocalCurrency_MembershipDues,
       CPPT.Price * #ToUSDPlanRate.PlanRate as USD_MembershipDues,    
       CPPT2.Price * #PlanRate.PlanRate AS ClubJuniorDuesPrice,
       CPPT2.Price AS LocalCurrency_ClubJuniorDuesPrice,
       CPPT2.Price * #ToUSDPlanRate.PlanRate AS USD_ClubJuniorDuesPrice   
/***************************************/

  FROM vClub C
  JOIN vMembership MS
    ON MS.ClubID=C.ClubID
  JOIN vMember M
    ON M.MembershipID=MS.MembershipID
  JOIN vValRegion R
    ON R.ValRegionID=C.ValRegionID
  JOIN vValMemberType VMT
    ON  VMT.ValMemberTypeID=M.ValMemberTypeID
  JOIN vCompany CO
    ON MS.CompanyID=CO.CompanyID
  JOIN #CompanyIDList CIDL
    ON CO.CompanyID = CIDL.CompanyID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID=MT.MembershipTypeID
  JOIN vProduct P
    ON P.ProductID=MT.ProductID
  JOIN vClubProductPriceTax CPPT
    ON CPPT.ProductID = P.ProductID
   AND CPPT.ClubID = MS.ClubID
  JOIN vValCurrencyCode VCC
    ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
    ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
   AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
    ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
   AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
  LEFT JOIN vValTaxType VTT
    ON CPPT.ValTaxTypeID = VTT.ValTaxTypeID
  JOIN vClubProductPriceTax CPPT2
    ON CPPT.ClubID = CPPT2.ClubID
   AND (CPPT.ValTaxTypeID = CPPT2.ValTaxTypeID OR CPPT.ValTaxTypeID IS NULL)
   AND MS.JrmemberDuesproductID = CPPT2.ProductID ----- Junior Membership Dues Product code updated on 12/07/2012
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID=VMS.ValMembershipStatusID
 WHERE M.ValMemberTypeID IN(1,4)
   AND M.ActiveFlag = 1 
   AND VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination')

DROP TABLE #CompanyIDList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
