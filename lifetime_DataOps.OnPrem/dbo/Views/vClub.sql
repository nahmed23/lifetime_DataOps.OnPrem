﻿CREATE VIEW dbo.vClub AS 
SELECT ClubID,ValRegionID,StatementMessageID,ValClubTypeID,DomainNamePrefix,ClubName,ReceiptFooter,DisplayUIFlag,CheckInGroupLevel,ValStatementTypeID,ChargeToAccountFlag,ValPreSaleID,ClubActivationDate,ValTimeZoneID,InsertedDateTime,ValCWRegionID,EFTGroupID,GLTaxID,GLClubID,CRMDivisionCode,AssessJrMemberDuesFlag,SellJrMemberDuesFlag,UpdatedDateTime,ClubCode,SiteID,NewMemberCardFlag,ValMemberActivityRegionID,IGStoreID,ChildCenterWeeklyLimit,ValSalesAreaID,ValPTRCLAreaID,FormalClubName,KronosForecastMapPath,ClubDeActivationDate,GLCashEntryAccount,GLReceivablesEntryAccount,GLCashEntryCashSubAccount,GLCashEntryCreditCardSubAccount,GLReceivablesEntrySubAccount,GLCashEntryCompanyName,GLReceivablesEntryCompanyName,MarketingMapRegion,MarketingMapXmlStateName,MarketingClubLevel,ValCurrencyCodeID,AllowMultipleCurrencyFlag,WorkdayRegion,AllowJuniorCheckInFlag,LTFResourceID,HealthClubIdentifier,MaxJuniorAge,MaxSecondaryAge,ChargeNextMonthDate,MinFrontDeskCheckinAge,MaxChildCenterCheckinAge,StateCancellationDays,EliteClubFlag,ChildCenterDailyLimit,MarketRatePricingFlag
FROM MMS.dbo.Club WITH(NOLOCK)
