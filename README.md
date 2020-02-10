# ab_test_imbalanced

Evaluate results of A/B test with imperfect randomization.  

**Objective:** Recommend whether app feature should be rolled out, and to which users.

**Data description:** Minutes on app pre- and post-experiment; user characteristics and treatment assignment. Treatment was assigned at the user level.

**Methods:** Difference-in-differences regression.

**Conclusions:** The new feature increases minutes on the app across all users, and has either a positive effect or no effect within each user type. Therefore, we recommend rolling out the feature to all users.    

**Findings:** 

There were issues with treatment assignment. Average active minutes in the pre-experiment period are significantly lower for treated users than control users. Likelihood of treatment differed significantly by user type and was highest for new users (25%) and lowest for viewers (12%), but did not differ by gender.

<img src="https://github.com/AidanMK/ab_test_imbalanced/blob/master/plots/trends_all.png" width="600" height="450">
