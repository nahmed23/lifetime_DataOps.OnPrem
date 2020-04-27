CREATE TABLE [dbo].[tmpMembershipShift] (
    [AddToClubCounter]           INT            NULL,
    [AddMembershipToClub]        NVARCHAR (255) NULL,
    [RegionPlus]                 NVARCHAR (255) NULL,
    [UniqueClubFlag]             INT            NULL,
    [SubtractmembershipFromClub] NVARCHAR (255) NULL,
    [MembershipTypeDescription]  NVARCHAR (255) NULL,
    [RegionMinus]                NVARCHAR (255) NULL,
    [DuesPrice]                  FLOAT (53)     NULL,
    [Membershipid]               INT            NULL,
    [AddClubID]                  INT            NULL,
    [SubClubID]                  INT            NULL,
    [MembershipTypeID]           INT            NULL
);

