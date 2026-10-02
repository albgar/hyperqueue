program producer
    use, intrinsic :: iso_fortran_env, only: int32, real64
    implicit none

    integer, parameter :: count = 10
    integer(int32) :: values(count)
    real(real64) :: random_values(count), factor
    integer :: unit

    call random_number(random_values)
    values = int(random_values * 100.0_real64, int32) + 1_int32
    call random_number(factor)

    open(newunit=unit, file='producer-array.bin', access='stream', form='unformatted', &
         status='replace', action='write')
    write(unit) values
    close(unit)

    open(newunit=unit, file='producer-factor.bin', access='stream', form='unformatted', &
         status='replace', action='write')
    write(unit) factor
    close(unit)

    print '(a, 10(1x, i0))', 'Producer array:', values
    print '(a, f0.6)', 'Producer factor: ', factor
end program producer
