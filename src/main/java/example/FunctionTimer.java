package example;

/**
 * Simple utility to time a function. It is rudimentary, it allows no nested
 * timing.
 */
public class FunctionTimer
{
    private long timer = 0;
    private String nameTimer = "";

    /**
     * Start the timer
     */
    public void startTimer(String name)
    {
        nameTimer = name;
        timer = System.nanoTime();
    }

    /**
     * Print the timer result
     */
    public String stopTimer()
    {

        long duration = System.nanoTime() - timer;
        String time_str = (
            " *** <profile> [" + nameTimer + "] # " +
            duration / 1000000 + " ms.");
        nameTimer = "";
        timer = 0;
        return time_str;
    }

}
