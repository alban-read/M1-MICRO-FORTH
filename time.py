 

import time


def F(n):
  if n == 0: return 0
  elif n == 1: return 1
  else: return F(n-1)+F(n-2)

start_time = time.time()

for x in range(25):
  F(34)BYE
  

finish_time=time.time()

print( finish_time - start_time)