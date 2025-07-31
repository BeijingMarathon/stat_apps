# Python scripts for analyzing the airline flight data
# -*- coding: utf-8 -*-
"""
Created on Jul 26 21:28:53 2024

@author: Bogong Timothy Li
"""
#!/usr/bin/env python
# coding: utf-8

## Introduction 
# Import required libraries
import os
import pandas as pd
import numpy as np 
import matplotlib.pyplot as plt
from pandas.plotting import scatter_matrix
import seaborn as sns

# Set the global plot font size to 8
plt.rcParams['font.size'] = 8 

# Load data
# Note: flights.csv columns (3,13,14) have mixed types
DataChallenge_path = "C:/Temp/DataChallenge/data"
# flights_path = os.path.join(DataChallenge_path, "flights.csv")
flights = pd.read_csv(os.path.join(DataChallenge_path, "flights.csv"), low_memory=False)
tickets = pd.read_csv(os.path.join(DataChallenge_path, "tickets.csv"))
airport_codes = pd.read_csv(os.path.join(DataChallenge_path, "airport_codes.csv"))


## Data Quality Check - Accuracy, Completeness, and Consistency 
# QA airport_codes data ----
# Clean airport_codes data before it is merged with flights
# Remove airports that:
#   1. do not have IATA CODE, "", or 
#   2. with values, or 
#   3. "-" and "0"
airport_codes2 = (airport_codes
                 .drop_duplicates(subset='IATA_CODE')
                 .loc[~airport_codes['IATA_CODE']
                 .isin(["", "-", "0"]), ['TYPE', 'IATA_CODE']])

# Find IATA codes of large and medium airports
code_use = airport_codes2.loc[airport_codes2['TYPE']
            .isin(['medium_airport', 'large_airport']) & (airport_codes2['IATA_CODE'] != ""), 'IATA_CODE'] \
            .drop_duplicates()

# Data Cleaning `flights`
# Plotting bivariate correlation and histograms
#  - Computing-intensive -
attributes = ['DEP_DELAY', 'ARR_DELAY', 'OCCUPANCY_RATE']
scatter_matrix(flights[attributes], figsize=(9,6))


# QA flights ----
# Remove possible erroneous records based on departure and arrival delays
fig, ax = plt.subplots(figsize=(8, 5))
sns.boxplot(x='OP_CARRIER', y='DEP_DELAY', data=flights)
plt.title("Departure Delay by Carrier")
plt.show()

# Arrival delays
fig, ax = plt.subplots(figsize=(8, 5))
sns.boxplot(x='OP_CARRIER', y='ARR_DELAY', data=flights)
plt.title("Departure Delay by Carrier")
plt.show()

# 53 flights delayed more than 24 hours
flights[flights['ARR_DELAY'] > 1440].shape[0]

# 45 flights departing with delay more than 24 hours
flights[flights['DEP_DELAY'] > 1440].shape[0]

# Potential flight distance errors: 2740 flights with NA DISTANCE, 250 flights with less than 10 miles DISTANCE
flights['DISTANCE'] = pd.to_numeric(flights['DISTANCE'], errors='coerce')
flights[flights['DISTANCE'].isna()].shape[0]
flights[flights['DISTANCE'] < 10].shape[0]

# Clean flights2 data  ----
# Convert data type: Distance, char -> numeric
# Add airport types to both the origin and destination airports
# Remove:
#   1. TAIL_NUM is "", 
#   2. Cancelled flights, 
#   3. Airports that are neither large nor medium airports
#   4. Departure delay greater than 1440 minutes (45 removed)
#   5. Arrival delay greater than 1440 min. (53 removed)
#   6. Distance is missing or less than 10, possible error

flights2 = flights.copy()
flights2['DISTANCE'] = pd.to_numeric(flights2['DISTANCE'], errors='coerce')
flights2 = flights2.merge(airport_codes2, left_on='ORIGIN', right_on='IATA_CODE', how='left').rename(columns={'TYPE': 'type_orig'})
flights2 = flights2.merge(airport_codes2, left_on='DESTINATION', right_on='IATA_CODE', how='left').rename(columns={'TYPE': 'type_dest'})
flights2 = flights2[(flights2['TAIL_NUM'] != "") & 
                    (flights2['CANCELLED'] != 1) & 
                    (flights2['type_orig'].isin(['medium_airport', 'large_airport'])) & 
                    (flights2['type_dest'].isin(['medium_airport', 'large_airport'])) & 
                    (flights2['DEP_DELAY'] < 1440) & 
                    (flights2['ARR_DELAY'] < 1440) & 
                    (flights2['DISTANCE'].notna()) & 
                    (flights2['DISTANCE'] > 10)]


## Problem 1 - The Top-10 Busiest Round-Trip US Airports 

# Add round-trip indicator for each flight to flights2 data:
# Definition of a Round-Trip: Given any day, the same airplane starts and returns to the same airport
#                             It might have come back directly from a destination, 1-leg; this is counted.
#                             Or if it might have flown to a second, or third destination, multi-leg, this is not counted
# Given the same FL_DATE and TAIL_NUM, 
#   roundtrip=1 if current "ORIGIN" is the "DESTINATION", and current "DESTINATION" is the "ORIGIN" of another flight; 
#   roundtrip=0 otherwise
# Function -----------
# Add indicator "roundtrip" to define if a flight is a round-trip flight
# Input: DF with variables as in flight
# Output: Same DF as input with added round-trip indicator "roundtrip"
def indicate_round_trip(dat):
    for i in range(len(dat)):
        for j in set(range(len(dat))) - {i}:
            if dat.iloc[i]['ORIGIN'] == dat.iloc[j]['DESTINATION'] and dat.iloc[i]['DESTINATION'] == dat.iloc[j]['ORIGIN']:
                dat.at[dat.index[i], 'roundtrip'] = 1
    return dat

## flights3 data with added roundtrip, route and ticket_route vars ----
# - Computing Intensive (about 20 mins) -
start_time = pd.Timestamp.now()
df_wk = flights2.copy()
df_wk['roundtrip'] = 0
df_wk['ticket_route'] = df_wk[['ORIGIN', 'DESTINATION']].apply(lambda x: '_'.join(x), axis=1)
df_wk['route'] = df_wk[['ORIGIN', 'DESTINATION']].apply(lambda x: '_'.join(sorted(x)), axis=1)

temp = [group for _, group in df_wk.groupby(['FL_DATE', 'TAIL_NUM'])]

flights3 = pd.concat([indicate_round_trip(group) for group in temp], ignore_index=True)

end_time = pd.Timestamp.now()
time_taken = end_time - start_time
print(time_taken)

flights3.query('roundtrip == 1')

# Dates and airplanes made more than one round trip (2 flights) in a day
evidence = (flights3[flights3['roundtrip'] == 1]
            .groupby(['FL_DATE', 'TAIL_NUM'])
            .size()
            .reset_index(name='n')
            .query('n > 2'))
evidence

# Top 10 busiest round-trip routes with the number of flights
top_routes = (flights3[flights3['roundtrip'] == 1]
              .groupby('route')
              .size()
              .reset_index(name='flights')
              .sort_values(by='flights', ascending=False)
              .head(10))
top_routes

fig, ax = plt.subplots(figsize=(9,3))
bar_container = ax.bar(top_routes['route'], top_routes['flights'])
ax.set(ylabel='Number of Flights', title='Number of Flights of Top 10 Most Busiest US Round-Trip Flight Routes in Q1-2019', ylim=(0, 7000))
ax.set(xlabel='Round-Trip Routes')
ax.bar_label(bar_container, fmt='{:,.0f}')


## Problem 2 - The Top-10 Most Profitable Round-Trip Routes 
### Data Cleaning `tickets`
tickets[(tickets['ROUNDTRIP'] == 1)]

## QA tickets data ----
# Duplicated itinerary
duplicated_itineraries = (tickets[(tickets['ROUNDTRIP'] == 1) & 
                                   (tickets['ORIGIN'].isin(code_use)) & 
                                   (tickets['DESTINATION'].isin(code_use))]
                          .groupby('ITIN_ID')
                          .size()
                          .reset_index(name='n')
                          .query('n > 1'))

## tickets2, cleaned ----
# Remove: 1. One-way trips, 2. non-large, medium airports, 3. fare price is "", 
#         3. Passenger is NA (1977), 4. completely duplicated rows
# Convert ITIN_FARE from CHAR to NUMERIC
# Remove ITIN_FARE is missing
# Remove fare values of $0 (5571), 
# Remove price more than $5,000, either record error or untypical fare

tickets_temp = (tickets[(tickets['ROUNDTRIP'] == 1) & 
                        (tickets['ORIGIN'].isin(code_use)) & 
                        (tickets['DESTINATION'].isin(code_use)) & 
                        (tickets['ITIN_FARE'] != "") & 
                        (tickets['PASSENGERS'].notna())]
                .drop_duplicates()
                .assign(ITIN_FARE=lambda x: pd.to_numeric(x['ITIN_FARE'], errors='coerce'))
                .dropna(subset=['ITIN_FARE'])
                .query('ITIN_FARE != 0 & ITIN_FARE < 5000')
                [['ITIN_ID', 'ORIGIN', 'DESTINATION', 'PASSENGERS', 'ITIN_FARE']])

# QA - Remove these 313, because they will lead to wrong calculations for average fare of routes
itin_rm = tickets_temp.groupby('ITIN_ID').filter(lambda x: len(x) > 1)['ITIN_ID'].unique()

tickets2 = (tickets_temp[~tickets_temp['ITIN_ID'].isin(itin_rm)]
             .assign(tot_fare=lambda x: x['PASSENGERS'] * x['ITIN_FARE'])
             .assign(ticket_route=lambda x: x['ORIGIN'] + '_' + x['DESTINATION']))


### Estimating Average Round-Trip Fare
## Average fare by directional ticket route ----
tickets3 = (tickets2.groupby('ticket_route')
             .agg(avg_fare=('tot_fare', 'sum'), 
                  total_passengers=('PASSENGERS', 'sum'))
             .assign(avg_fare=lambda x: x['avg_fare'] / x['total_passengers'])
             .reset_index())

# - LIMITATION - of the analysis: only round-trip routes with round-trip fare info in tickets may be compared
# flights without fare info from the tickets sample will be dropped, 452936 remain 
flights4 = (flights3[flights3['roundtrip'] == 1]
             .merge(tickets3, on='ticket_route', how='left')
             .dropna(subset=['avg_fare']))

### Find the Most Profitable Routes
## Most profitable routes ----
flights_w_profit = (flights4.assign(revenue=lambda x: (x['avg_fare'] + 70) * 200 * x['OCCUPANCY_RATE'],
                                     cost=lambda x: (8 + 1.18) * x['DISTANCE'] * 2 + 
                                                     np.where(x['type_orig'] == "medium_airport", 5000, 10000) +
                                                     np.where(x['type_dest'] == "medium_airport", 5000, 10000) +
                                                     (x['DEP_DELAY'].clip(lower=15) - 15) * 75 + 
                                                     (x['ARR_DELAY'].clip(lower=15) - 15) * 75,
                                     profit=lambda x: x['revenue'] - x['cost']))
flights_w_profit

# The most profitable round-trip routes
profit = (flights_w_profit.groupby('ticket_route')
          .agg(Tot_Profit=('profit', 'sum'), 
               Tot_Revenue=('revenue', 'sum'), 
               Tot_Cost=('cost', 'sum'), 
               Distance=('DISTANCE', 'mean'), 
               Avg_Fare=('avg_fare', 'mean'), 
               N_Flights=('ticket_route', 'size'))
          .reset_index()
          .sort_values(by='Tot_Profit', ascending=False)
          .assign(rank_profit=lambda x: range(1, len(x) + 1)))

profit

# The recommended top-10 routes with most profits
fig, ax = plt.subplots(figsize=(12,3))
bar_container = ax.bar(profit['ticket_route'].iloc[0:10], profit['Tot_Profit'].iloc[0:10])
ax.set(ylabel='Total Profit - Q1 2019 ($)', title='Total Profits of Top 10 Most Profitable US Round-Trip Flight Routes in Q1-2019', ylim=(0, 80000000))
ax.set(xlabel='Round-Trip Routes')
ax.bar_label(bar_container, fmt='{:,.0f}')


## Problem 3 - The Recommended Top-5 Round-Trip Routes 
### Recommendation Criteria

# Filter data by the top ten profitable routes
choice = profit["ticket_route"].iloc[:10]
choice

# "On Time" is defined as the average of the absolute value of the arrival delay; 
#          either early or late arrival is not considered "On Time", and is equally undesiarable
Best5 = (flights_w_profit[flights_w_profit['ticket_route'].isin(choice)]
          .assign(abs_arr_delay=flights_w_profit['ARR_DELAY'].abs())
          .groupby('ticket_route', as_index=False)
          .agg(avg_arr_delay=('abs_arr_delay', 'mean'))
          .merge(profit, on='ticket_route')
          .sort_values('avg_arr_delay')
          .assign(rank_onTime=lambda x: np.arange(1, len(x) + 1)))
Best5

# Top 10 most profitable flights tend to have below-average arrival delays
df_avg_arr_delay = flights_w_profit.assign(abs_arr_delay=flights_w_profit['ARR_DELAY'].abs()) \
    .groupby('ticket_route', as_index=False) \
    .agg(avg_arr_delay=('abs_arr_delay', 'mean'))

fig, ax = plt.subplots(figsize=(8,3))
plt.hist(df_avg_arr_delay['avg_arr_delay'], bins=100, range=(0, 100))
plt.title("Distribution of Average Absolute Value of Flight Arrival Delays on Round-Trip Routes")
plt.show()

df_avg_arr_delay.describe()

### The Five Recommended Routes

# These top 5 recommend routes for investiment are:
routes_choice = (Best5.iloc[0:5]
                 .merge(flights4.drop_duplicates(subset='ticket_route'), on='ticket_route', how='left')
                 [['ORIGIN', 'ORIGIN_CITY_NAME', 'DESTINATION', 'DEST_CITY_NAME', 'DISTANCE', 'rank_profit', 'rank_onTime']])
routes_choice

# The recommended top-5 routes with lowest arrival delays among top-10 most profitable routes
# Apprival delay is highly correlated with arrival delay
fig, ax = plt.subplots(figsize=(8,3))
bar_container = ax.bar(Best5['ticket_route'].iloc[0:5], Best5['avg_arr_delay'].iloc[0:5])
ax.set(ylabel='Average Arrival Delay (minutes)', title='Average Arrival Delay of Top 5 Recommended US Round-Trip Flight Routes', ylim=(0, 22))
ax.set(xlabel='Round-Trip Routes')
ax.bar_label(bar_container, fmt='{:,.0f}')

# Total profits of the recommended top-5 routes
fig, ax = plt.subplots(figsize=(8,3))
bar_container = ax.bar(Best5['ticket_route'].iloc[0:5], Best5['Tot_Profit'].iloc[0:5])
ax.set(ylabel='Total Profits ($)', title='Total Profit of the Top 5 Recommended US Round-Trip Flight Routes Q1-2019', ylim=(0, 70101972))
ax.set(xlabel='Round-Trip Routes')
ax.bar_label(bar_container, fmt='{:,.0f}')


## Problem 4 - The Breakeven Flights for the 5 Recommended Routes 
# Estimate per-flight profit on the round-trip route, then divided 90 mil by it to have breakeven number of round-trip flights
Best5['prof_p_rtrip'] = Best5['Tot_Profit'] / Best5['N_Flights']
Best5['N_rTrips'] = (90000000 / Best5['prof_p_rtrip']).round()
Breakeven = Best5.head(5)
Breakeven

# The number of round-trip flights to break even on the upfront airplane cost - "N_rTrips"
Breakeven[['ticket_route', 'rank_onTime', 'rank_profit', 'N_rTrips']]

# - END -
