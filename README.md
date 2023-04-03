# Start Stop VMs by TAG

    .DESCRIPTION
        Runbook to Start / Stop VMs in a ResourceGroup using the Run As Account (Service Principal)

    .NOTES
        AUTHOR: Ivan PATILLON - Oceanet Technology
        LASTEDIT: 19 March 2020

        MUST BE CALLED WITH PARAMETER ResourceGroupList containing list of ResourceGroups to search VMs with Tags
        example : ["my-rg1","my-rg2"]

        Tags needed :
            StartAt (hour time between 0 to 23)
                example : 7
            StopAt (hour time between 0 to 23)
                example : 20
            StartStopDays (8 bits number with higher bit to 0 or 1 for all days)
                example : "111110" or "00111110" for dimanche 0 lundi 1 mardi 1 mercredi 1 jeudi 1 vendredi 1 samedi 0 Everyday 0
                example : "110000" or "00110000" for dimanche 0 lundi 0 mardi 0 mercredi 0 jeudi 1 vendredi 1 samedi 0 Everyday 0
                example : "10000000"             for dimanche 0 lundi 0 mardi 0 mercredi 0 jeudi 0 vendredi 0 samedi 0 Everyday 1
