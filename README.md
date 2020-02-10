# ab_test_imbalanced

Evaluate results of A/B test with imperfect randomization.  

**Objective:** Recommend whether app feature should be rolled out, and to which users.

**Data description:** Minutes on app pre- and post-experiment; user characteristics and treatment assignment. Treatment was assigned at the user level.

**Methods:** Difference-in-differences regression.

**Conclusions:** The new feature increases minutes on the app across all users, and has either a positive effect or no effect within each user type. Therefore, we recommend rolling out the feature to all users.    

**Analysis and findings:** 

There were issues with treatment assignment in this experiment. Likelihood of treatment differed significantly by user type and was highest for new users (25%) and lowest for viewers (12%), but did not differ by user gender. Moreover, average minutes in the pre-experiment period are significantly lower for treated users than control users. As a result, we need to take pre-treatment differences into account when estimating the effect of the new feature. 

The figure below shows daily minutes per user before and after the start of the experiment. 

*All users* 

<img src="https://github.com/AidanMK/ab_test_imbalanced/blob/master/plots/trends_all.png" width="600" height="450">

Since treated and control users have parallel trends in the pre-experiment period, a difference-in-differences methodology can be used to estimate the causal effect of the treatment. The regression shows that treated users increased minutes on the app by 15 percent, which is significant at the 5 percent level (standard errors are clustered at the user level).  

*By user type* 

<img src="https://github.com/AidanMK/ab_test_imbalanced/blob/master/plots/trends_viewer.png" width="600" height="450">

<img src="https://github.com/AidanMK/ab_test_imbalanced/blob/master/plots/trends_nonviewer.png" width="600" height="450">

<img src="https://github.com/AidanMK/ab_test_imbalanced/blob/master/plots/trends_newuser.png" width="600" height="450">


