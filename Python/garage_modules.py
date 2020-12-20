def GPIO_wait(section, shm):
        i = 0
        print("gpio buf = " + str(shm))
        while ((shm != 0) and (shm != 1)):
                if ((i % 1000) == 0):
                    print("aws waiting at " + str(section) + "... i = " + str(i) + " shm = " + str(shm))
                i = i + 1
        print("Exiting Wait... shm = " +str(shm))
