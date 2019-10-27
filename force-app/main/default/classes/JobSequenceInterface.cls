/**
 * Copyright 2019 Jason Hardy
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * ----------------------------------------------------------------------------------------
 *
 * Implementing this interface allows you to create a customized job sequence handler. This is helpful when you need
 * to have custom logic (especially for functions) that will execute when a job sequence is initiated. You will need to
 * pass the name of the class that implements this class into the Sequence Job Custom Metadata record for the jobs you
 * wish to execute with the custom handler for this interface.
 */
global interface JobSequenceInterface {

    /**
     * This method will execute functions based on the function name defined in the "Execution Job" defined on the
     * sequence job custom setting, which is translated into a jobs sequence object wrapper. Each function has to be
     * defined as an option in a case statement (or if statements whichever works best for you), pointing to the
     * appropriate function either in this class or in another.
     *
     * Having the ability to run a function provides you with the ability to scale your job sequences. By providing an
     * interface you may work with, you can either adapt this class or create your own and point the sequence job custom
     * metadata type to the "Handler" of your choice. Thus you can create custom functions that meet the business needs
     * for the jobs you need to have executed in a serial fashion.
     *
     * You are able to scale this further by using parameters which can be defined in a JSON fashion in either a test
     * or production fashion, see the documentation for further details.
     *
     * @param js    The job sequence wrapped object containing the logic needed to execute the function
     * @param scope The records to be worked with
     */
    void executeFunction(JobSequence js, List<SObject> scope);

    /**
     * This method will simply run a DML option based on how you've defined it in the Sequence Job Custom Meta data type
     *
     * @param js    The job sequence wrapped object containing the logic needed to execute the function
     * @param scope The records to be worked with
     */
    void executeDML(JobSequence js, List<SObject> scope);

    /**
     * If you wish some custom logic to be executed when the job sequence is completed, this is where you can do so.
     * An example would be sending an email to let someone know that the sequence has been completed successfully.
     *
     * @param js    The job sequence wrapped object containing the logic needed to execute the function
     */
    void finishJobSequence(JobSequence js);
}