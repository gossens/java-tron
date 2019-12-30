package org.tron.common.secret.usdt;

import lombok.Getter;
import lombok.Setter;
import org.apache.commons.lang3.tuple.Pair;
import org.spongycastle.util.encoders.Hex;
import org.tron.common.utils.ByteUtil;

import java.util.Arrays;

public class PrecompiledContracts {

    private static final DataWord verifyProofAddr = new DataWord(
            "000000000000000000000000000000000000000000000000000000000001000F");

    private static final verifyProofContract verifyProofContract = new verifyProofContract();

    public static PrecompiledContract getContractForAddress(DataWord address) {

        if (address.equals(verifyProofAddr)) {
            return verifyProofContract;
        }

        return null;
    }
    public static abstract class PrecompiledContract {

        public abstract long getEnergyForData(byte[] data);

        public abstract Pair<Boolean, byte[]> execute(byte[] data);

        private byte[] callerAddress;

        public void setCallerAddress(byte[] callerAddress) {
            this.callerAddress = callerAddress.clone();
        }

        public void setDeposit(Deposit deposit) {
            this.deposit = deposit;
        }

        public void setResult(ProgramResult result) {
            this.result = result;
        }

        private Deposit deposit;

        private ProgramResult result;

        public byte[] getCallerAddress() {
            return callerAddress.clone();
        }

        public Deposit getDeposit() {
            return deposit;
        }

        public ProgramResult getResult() {
            return result;
        }


        @Getter
        @Setter
        private boolean isStaticCall;

        @Getter
        @Setter
        private long vmShouldEndInUs;


        public long getCPUTimeLeftInUs() {
            long vmNowInUs = System.nanoTime() / 1000;
            long left = getVmShouldEndInUs() - vmNowInUs;
            if (left <= 0) {
                throw Program.Exception.notEnoughTime("call");
            } else {
                return left;
            }
        }
    }

    public static class verifyProofContract extends PrecompiledContract {
        @Override
        public long getEnergyForData(byte[] data) {
            return 0;
        }

        @Override
        public Pair<Boolean, byte[]> execute(byte[] data) {
            if (isStaticCall()) {
                return Pair.of(true, new DataWord(0).getData());
            }
            if (data == null || data.length != 5 * DataWord.WORD_SIZE) {
                return Pair.of(false, new DataWord(0).getData());
            }
            if (!checkInGatewayList(this.getCallerAddress(), getDeposit())) {
                logger.error("[mineToken method]caller must be gateway, caller: %s",
                        Wallet.encode58Check(this.getCallerAddress()));
                throw new PrecompiledContractException(
                        "[mineToken method]caller must be gateway, caller: %s",
                        Wallet.encode58Check(this.getCallerAddress()));
            }

            long amount = new DataWord(Arrays.copyOf(data, 32)).sValue().longValueExact();

            byte[] tokenId = new DataWord(Arrays.copyOfRange(data, 32, 64)).getData();

            byte[] tokenIdWithoutLeadingZero = ByteUtil.stripLeadingZeroes(tokenId);
            byte[] tokenIdLongBytes = String
                    .valueOf(Long.parseLong(Hex.toHexString(tokenIdWithoutLeadingZero), 16)).getBytes();

            byte[] tokenName = new DataWord(Arrays.copyOfRange(data, 64, 96)).getData();

            byte[] symbol = new DataWord(Arrays.copyOfRange(data, 96, 128)).getData();

            int decimals = new DataWord(Arrays.copyOfRange(data, 128, 160)).sValue().intValueExact();

            checkProofProcess();

            getDeposit().addTokenBalance(this.getCallerAddress(), tokenIdLongBytes, amount);

            return Pair.of(true, EMPTY_BYTE_ARRAY);
        }

        private void checkProofProcess() {

        }

    }
}
