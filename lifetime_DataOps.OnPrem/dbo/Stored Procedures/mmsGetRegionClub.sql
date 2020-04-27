

-- =============================================
-- Object:			dbo.mmsGetRegionClub
-- Author:			Greg Burdick
-- Create date:		
-- Release date:	6/18/2008 dbcr_3274
-- Description:		This query returns all regions and their related clubs and 
--					club IDs used for the creation of UI list boxes.
-- Modified date:	6/10/2008 GRB: added ValRegionID to end of select statement
--                  9/26/2008 SRM: added PTRCLArea and SalesArea related columns
--                  05/13/2011 RC: added ClubDeactivationDate to select statement
--                  6/29/2011 BSD: added LocalCurrencyCode
-- EXEC mmsGetRegionClub
-- =============================================

CREATE          PROCEDURE [dbo].[mmsGetRegionClub] 
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY


SELECT R.Description AS RegionDescription, 
		C.ClubID, C.ClubName, 
		C.DisplayUIFlag, C.ClubActivationDate,C.DomainNamePrefix,
		C.CRMDivisionCode, C.ClubCode, C.GLClubID,C.ValPreSaleID,
		C.ValMemberActivityRegionID, VMAR.Description AS MemberActivitiesRegionDescription,
		R.ValRegionID,C.ValPTRCLAreaID, VA.Description AS PTRCLArea,C.ValSalesAreaID, 
        SA.Description AS SalesArea,
        C.ClubDeactivationDate,
        PER.PlanExchangeRate PlanExchangeRate_ToUSD_ForYesterday,
        VCC.CurrencyCode LocalCurrencyCode
  FROM vClub C 
  JOIN vValRegion R 
       ON C.ValRegionID=R.ValRegionID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  LEFT JOIN vValMemberActivityRegion VMAR
       ON C.ValMemberActivityRegionID = VMAR.ValMemberActivityRegionID
  LEFT JOIN vValPTRCLArea VA 
       ON VA.ValPTRCLAreaID = C.ValPTRCLAreaID
  LEFT JOIN vValSalesArea SA
       ON SA.ValSalesAreaID = C.ValSalesAreaID
  LEFT JOIN vPlanExchangeRate PER
       ON VCC.CurrencyCode = PER.FromCurrencyCode
      AND PER.ToCurrencyCode = 'USD'
      AND PER.PlanYear = YEAR(DATEADD(DD,-1,GETDATE()))


 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity


END
